# Aegis Backend

FastAPI service powering Aegis's check-in reasoning, daily stories, rules dictionary retrieval, voice narration, and progress tracking.

## Structure

```
app/
├── graphs/          # LangGraph flows
│   ├── checkin.py       # intake → clarify → retrieve → classify → verdict → teach_back → grade
│   ├── prompts.py       # system prompts, few-shot examples, grading/teach-back prompts
│   └── story.py         # daily story generation flow
├── models/          # Pydantic schemas
├── rag/             # Retrieval layer
│   ├── embeddings.py    # Bedrock Titan Embeddings wrapper
│   └── store.py         # ChromaDB-backed rules retrieval, country-scoped + universal fallback
├── routers/         # API endpoints
│   ├── checkin_ws.py    # WebSocket transport for the check-in graph
│   ├── rules.py         # GET /rules/dictionary
│   ├── stats.py         # progress/XP/streak endpoints
│   ├── story.py         # daily story endpoints
│   └── tts.py           # AWS Polly narration endpoint
├── security/        # Guardrail checks (AWS Bedrock Guardrails)
├── services/        # Supporting services
│   ├── stats_store.py   # progress persistence (DynamoDB)
│   └── tts_service.py   # Polly integration
└── main.py          # app entrypoint, router mounting

data/chroma/         # ChromaDB vector store (gitignored, regenerated via ingest_rules.py)

scripts/
├── ingest_rules.py      # (re)builds the Chroma collection from data/rules_dictionary_*.json
├── ws_smoke.py          # CLI websocket client for testing the check-in loop
├── test_pipeline.py     # intake → retrieve → classify → verdict test scenarios
├── test_grade.py        # teach-back grading test cases
└── test_intake.py       # intake extraction tests
```

## Setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in AWS credentials — see Environment Variables below
```

## Environment Variables

```dotenv
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=ap-south-1

# Separate model per node — intake extraction and teach-back grading
# use different models (see app/graphs/prompts.py)
BEDROCK_INTAKE_MODEL_ID=us.amazon.nova-pro-v1:0
BEDROCK_GRADE_MODEL_ID=us.amazon.nova-micro-v1:0

# Progress/XP/streak storage
DYNAMODB_TABLE_NAME=
DYNAMODB_REGION=ap-south-1
```


## Running

```bash
uvicorn app.main:app --reload
```

Re-run `python3 -m scripts.ingest_rules` after any change to `data/rules_dictionary_*.json` — the Chroma store isn't tracked in git and needs rebuilding from the source JSON each time.

## Notes

- Rules dictionary files are matched by the `country_code` field **inside** each JSON file, not by filename — `rules_dictionary_india.json` is named by country, not ISO code (`in`). Any new country's file should follow the same convention.
- `data/chroma/` is a regenerable build artifact — gitignored, never commit it.
- `MemorySaver` (the LangGraph checkpointer) is in-process only. Do not run `uvicorn --workers 2+` in this configuration, or check-in state won't be shared correctly across turns of the same conversation.