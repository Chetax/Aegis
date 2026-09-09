# backend/app/routers/checkin_ws.py
"""
Aegis — check-in websocket transport.

One socket message = one graph turn. The compiled `checkin_graph` owns all
reasoning; this router only relays. The graph pauses at every interrupt()
(each clarify question + the teach-back question); each pause is surfaced to the
client as a {"type": "question"} frame, and the client's next message resumes the
graph via Command(resume=...).

The graph has no knowledge of this transport — the same invoke/resume contract
would work over plain HTTP long-polling. Keeping the graph transport-agnostic is
deliberate: the Flutter client codes against the JSON contract below, not against
LangGraph internals.

--- Client <-> server contract -------------------------------------------------

Client -> server (JSON):
  first message : {"text": "<what the user said>",
                   "language": "en" | "hi",       # optional, default "en"
                   "country_code": "IN"}           # optional, default "IN"
  every reply   : {"text": "<answer to the question just asked>"}

Server -> client (JSON), exactly one frame per turn:
  {"type": "question", "field": "<state field>", "text": "<question>"}
      -> the graph is waiting; send the user's answer as the next message.
  {"type": "done", "result": { ...curated verdict payload... }}
      -> the check-in finished; the socket then closes.
  {"type": "error", "text": "<safe message>"}
      -> something failed; the socket then closes.

Note: the client does NOT need to know whether a question came from `clarify` or
from `teach_back` — it just answers. The `field` is provided so the UI *can*
branch if it wants (e.g. show a distinct teach-back screen when
field == "user_explanation").
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from langgraph.types import Command

from app.graphs.checkin import checkin_graph

router = APIRouter()


def _question_frame(interrupts) -> dict:
    """Shape a paused interrupt into the client-facing question frame.

    Every interrupt() in the graph passes {"question": ..., "field": ...}.
    """
    payload = interrupts[0].value
    return {
        "type": "question",
        "field": payload.get("field"),
        "text": payload.get("question", ""),
    }


def _result_frame(state: dict) -> dict:
    """Curate the final client payload.

    We deliberately do NOT dump the whole internal CheckinState — the client
    should depend only on this stable surface, not on internal field names or
    intermediate signals. Everything here is already grounded: `verdict_text` is
    template-built (never free-generated), and the source fields come straight
    from the matched rule.
    """
    return {
        "type": "done",
        "result": {
            "risk_level": state.get("risk_level"),
            "verdict_text": state.get("verdict_text", ""),
            "matched_category": state.get("matched_category"),
            "source": state.get("matched_source"),
            "source_url": state.get("matched_source_url"),
            "teach_back": {
                "question": state.get("teach_back_question"),
                "result": state.get("grade_result"),
                "feedback": state.get("grade_feedback", ""),
            },
        },
    }


@router.websocket("/ws/checkin/{session_id}")
async def checkin_ws(websocket: WebSocket, session_id: str):
    await websocket.accept()

    # thread_id keys this conversation's checkpoint in the graph's MemorySaver,
    # so interrupt() can persist state between turns and resume from it.
    config = {"configurable": {"thread_id": session_id}}
    started = False

    try:
        while True:
            msg = await websocket.receive_json()
            text = (msg or {}).get("text")
            if text is None:
                await websocket.send_json(
                    {"type": "error", "text": "Expected a JSON message with a 'text' field."}
                )
                # Malformed frame is recoverable — keep the socket open.
                continue

            try:
                if not started:
                    graph_input = {
                        "raw_description": text,
                        "language": msg.get("language", "en"),
                        "country_code": msg.get("country_code", "IN"),
                    }
                    # ainvoke runs the (synchronous) nodes in a threadpool, so the
                    # slow Bedrock calls inside them do NOT block the event loop and
                    # freeze other sockets. Never call the blocking .invoke() here.
                    result = await checkin_graph.ainvoke(graph_input, config)
                    started = True
                else:
                    result = await checkin_graph.ainvoke(Command(resume=text), config)
            except Exception:
                # A node (e.g. a Bedrock call) failed mid-turn. Don't leak
                # internals; fail safe with a conservative message, then close.
                await websocket.send_json(
                    {
                        "type": "error",
                        "text": (
                            "Something went wrong on our side. Please try again — and "
                            "if you're unsure about a call, hang up and verify using an "
                            "official number you look up yourself, not one you were given."
                        ),
                    }
                )
                break

            interrupts = result.get("__interrupt__")
            if interrupts:
                # Graph paused at an interrupt() — relay the question and loop
                # back to wait for the client's answer, which resumes the graph.
                await websocket.send_json(_question_frame(interrupts))
                continue

            # No interrupt -> the graph reached END. Send the verdict + grade.
            await websocket.send_json(_result_frame(result))
            break

    except WebSocketDisconnect:
        # Client hung up mid-conversation. The checkpoint for this thread_id
        # stays in memory; nothing else to clean up for the demo.
        return