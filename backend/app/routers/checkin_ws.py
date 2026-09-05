# backend/app/routers/checkin_ws.py
from fastapi import APIRouter, WebSocket
from langgraph.types import Command
from app.graphs.checkin import checkin_graph

router = APIRouter()

@router.websocket("/ws/checkin/{session_id}")
async def checkin_ws(websocket: WebSocket, session_id: str):
    await websocket.accept()
    config = {"configurable": {"thread_id": session_id}}
    started = False

    while True:
        msg = await websocket.receive_json()  # {"text": "<STT output>"}

        if not started:
            result = checkin_graph.invoke(
                {"raw_description": msg["text"], "language": msg.get("language", "en")},
                config,
            )
            started = True
        else:
            result = checkin_graph.invoke(Command(resume=msg["text"]), config)

        if "__interrupt__" in result:
            question = result["__interrupt__"][0].value["question"]
            await websocket.send_json({"type": "question", "text": question})
            continue

        # graph finished — send final payload (verdict, teach-back grade, etc.)
        await websocket.send_json({"type": "done", "state": result})
        break