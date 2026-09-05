"""
Aegis — Bedrock Titan embeddings wrapper.
"""

import os
from langchain_aws import BedrockEmbeddings

_embeddings = BedrockEmbeddings(
    model_id=os.getenv("BEDROCK_EMBED_MODEL_ID", "amazon.titan-embed-text-v2:0"),
    region_name=os.getenv("AWS_REGION", "us-east-1"),
)


def embed_texts(texts: list[str]) -> list[list[float]]:
    """Batch-embed a list of strings. Used by both ingestion and query."""
    return _embeddings.embed_documents(texts)


def embed_query(text: str) -> list[float]:
    """Embed a single query string."""
    return _embeddings.embed_query(text)