"""
Aegis — one-off / re-runnable ingestion script.

Reads every data/rules_dictionary_*.json file and (re)builds the Chroma
collection. Safe to re-run: clears and rebuilds rather than appending,
so stale entries never linger after a source file is edited.

Usage: python -m scripts.ingest_rules
"""

import glob
import json
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.rag.store import get_collection, COLLECTION_NAME, _client
from app.rag.embeddings import embed_texts

BASE_DIR = os.path.dirname(os.path.abspath(__file__))          # backend/scripts
DATA_GLOB = os.path.join(BASE_DIR, "..", "..", "data", "rules_dictionary_*.json")


def load_dictionaries() -> list[dict]:
    files = glob.glob(DATA_GLOB)
    if not files:
        raise FileNotFoundError(f"No files matched {DATA_GLOB}")
    return [json.load(open(f, encoding="utf-8")) for f in files]


def build_records(dictionaries: list[dict]) -> tuple[list[str], list[str], list[dict]]:
    ids, texts, metadatas = [], [], []

    for d in dictionaries:
        country_code = d["country_code"]

        for entry in d.get("entries", []):
            ids.append(entry["id"])
            texts.append(f"{entry['rule']} {entry['red_flag_context']}")
            metadatas.append({
                "country_code": country_code,
                "category": entry["category"],
                "rule": entry["rule"],
                "source": entry.get("source", ""),
                "source_url": entry.get("source_url", ""),
            })

        fallback = d.get("universal_fallback_patterns")
        if fallback:
            for i, pattern in enumerate(fallback["patterns"]):
                ids.append(f"universal-{i:03d}")
                texts.append(pattern)
                metadatas.append({
                    "country_code": "UNIVERSAL",
                    "category": "general_fallback",
                    "rule": pattern,
                    "source": "Aegis universal fallback set",
                    "source_url": "",
                })

    return ids, texts, metadatas


def main():
    dictionaries = load_dictionaries()
    ids, texts, metadatas = build_records(dictionaries)

    # Rebuild clean rather than upsert, so edited/removed entries don't linger.
    try:
        _client.delete_collection(COLLECTION_NAME)
    except Exception:
        pass
    collection = get_collection()

    embeddings = embed_texts(texts)
    collection.add(ids=ids, embeddings=embeddings, documents=texts, metadatas=metadatas)

    print(f"Ingested {len(ids)} entries across {len(dictionaries)} dictionary file(s).")
    for d in dictionaries:
        n = len(d.get("entries", []))
        print(f"  {d['country_code']}: {n} entries")


if __name__ == "__main__":
    main()