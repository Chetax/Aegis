"""
Aegis — Chroma-backed rules dictionary store.

Embeddings are computed externally via Bedrock Titan (embeddings.py) and
passed into Chroma directly, rather than using Chroma's built-in embedding
function, so the embedding model stays consistent between ingestion and
query and matches the rest of the AWS-based stack.
"""

import os
import chromadb

from .embeddings import embed_query

CHROMA_DIR = os.getenv("CHROMA_PERSIST_DIR", "./data/chroma")
COLLECTION_NAME = "rules_dictionary"

# Similarity below this is treated as "no confident match" — classify()
# should fall back to the most conservative verdict rather than trust a
# weak retrieval, consistent with the "default conservative" design rule.
CONFIDENCE_THRESHOLD = 0.35

_client = chromadb.PersistentClient(path=CHROMA_DIR)


def get_collection():
    return _client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"},  # so distance -> similarity = 1 - distance
    )

def get_by_category(category: str, country_code: str) -> list[dict]:
    """Direct metadata lookup, no embedding similarity involved — used
    for fixed 'always cite this' entries like reporting instructions,
    which should be surfaced by category, not by semantic match."""
    collection = get_collection()
    try:
        result = collection.get(
            where={"$and": [
                {"category": category},
                {"country_code": {"$in": [country_code, "UNIVERSAL"]}},
            ]}
        )
    except Exception:
        return []

    matches = []
    for rule_id, meta in zip(result.get("ids", []), result.get("metadatas", [])):
        matches.append({
            "id": rule_id,
            "category": meta.get("category"),
            "rule": meta.get("rule"),
            "source": meta.get("source"),
            "source_url": meta.get("source_url"),
        })
    return matches

def query_rules(query_text: str, country_code: str, k: int = 3) -> list[dict]:
    """Return up to k matches, each with similarity score, scoped to the
    given country plus the universal fallback patterns. Returns [] on
    any failure or empty collection — callers must treat that as
    'no signal', not 'confirmed safe'."""
    collection = get_collection()

    if collection.count() == 0:
        return []

    try:
        query_embedding = embed_query(query_text)
        result = collection.query(
            query_embeddings=[query_embedding],
            n_results=k,
            where={"country_code": {"$in": [country_code, "UNIVERSAL"]}},
        )
    except Exception:
        # Fail safe: retrieval breaking should not crash the check-in flow.
        # classify() sees an empty list and defaults conservative.
        return []

    matches = []
    ids = result.get("ids", [[]])[0]
    distances = result.get("distances", [[]])[0]
    metadatas = result.get("metadatas", [[]])[0]

    for rule_id, distance, meta in zip(ids, distances, metadatas):
        similarity = 1 - distance
        if similarity >= CONFIDENCE_THRESHOLD:
            matches.append({
                "id": rule_id,
                "category": meta.get("category"),
                "rule": meta.get("rule"),
                "source": meta.get("source"),
                "source_url": meta.get("source_url"),
                "similarity": round(similarity, 4),
            })

    return matches