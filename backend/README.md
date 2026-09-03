# Aegis Backend

FastAPI service — check-in/roleplay reasoning (LangGraph + Claude via Bedrock), rules-dictionary RAG, progress tracking.

## Structure
- `app/routers/` — story, checkin, roleplay, dictionary, progress endpoints
- `app/graphs/` — LangGraph flows (checkin, roleplay)
- `app/rag/` — ChromaDB retrieval over the rules dictionary
- `app/models/` — Pydantic schemas

## Setup
```
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```
