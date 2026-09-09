"""
Aegis — end-to-end websocket smoke test for the check-in graph.

Purpose: exercise the FULL interrupt -> resume loop that neither test_pipeline
nor test_grade touches (both skip the interrupt nodes). This is the first thing
that runs `clarify` + `teach_back` for real, over the actual transport.

Prereqs:
  1. AWS Bedrock creds in the environment (the graph nodes call Bedrock).
  2. Rules ingested:   cd backend && python3 -m scripts.ingest_rules
  3. Server running:    cd backend && uvicorn app.main:app --reload
  4. websockets client: pip install websockets

Run (in a second terminal):
  cd backend && python3 scripts/ws_smoke.py

It plays a scripted digital-arrest scenario: an opening description, then answers
to whatever clarify / teach-back questions come back, printing every frame. A
successful run ends with a `done` frame at risk_level "high", the in-006 source,
and a teach-back grade.
"""

import asyncio
import json
import uuid

import websockets

WS_BASE = "ws://127.0.0.1:8000/ws/checkin/"

# Opening turn.
OPENING = {
    "text": (
        "Someone called saying they are from the police and that my SIM card was "
        "used in a crime. They told me not to hang up and not to tell anyone, and "
        "to stay on a video call until I clear my name."
    ),
    "language": "en",
    "country_code": "IN",
}

# Canned answers, consumed in order as questions arrive (clarify, then teach-back).
ANSWERS = [
    "They asked me to transfer money to a safe account to prove I am innocent.",
    "Yes — they kept saying I must act right now or I will be arrested today.",
    "It felt wrong because they pressured me to act immediately and to keep it "
    "secret, and real police don't ask for money or a video call like that.",
]


async def main():
    session_id = str(uuid.uuid4())
    answers = iter(ANSWERS)

    async with websockets.connect(WS_BASE + session_id) as ws:
        await ws.send(json.dumps(OPENING))
        print(f"[client] opening sent (session {session_id[:8]})")

        while True:
            frame = json.loads(await ws.recv())
            ftype = frame.get("type")

            if ftype == "question":
                print(f"\n[aegis?] ({frame.get('field')}) {frame.get('text')}")
                reply = next(answers, "I'm not sure.")
                print(f"[user  ] {reply}")
                await ws.send(json.dumps({"text": reply}))

            elif ftype == "done":
                r = frame["result"]
                tb = r.get("teach_back", {})
                print("\n=== DONE ===")
                print(f"risk_level : {r.get('risk_level')}")
                print(f"verdict    : {r.get('verdict_text')}")
                print(f"category   : {r.get('matched_category')}")
                print(f"source     : {r.get('source')} ({r.get('source_url')})")
                print(f"teach-back : {tb.get('result')} — {tb.get('feedback')}")
                break

            elif ftype == "error":
                print(f"\n[error] {frame.get('text')}")
                break


if __name__ == "__main__":
    asyncio.run(main())