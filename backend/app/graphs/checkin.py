"""
Aegis — Check-in + Teach-back LangGraph

Flow:
    intake -> clarify (loops, capped) -> retrieve -> classify -> verdict -> teach_back -> grade -> END
"""

import json
import os
from typing import TypedDict, Optional, Literal

from langgraph.graph import StateGraph, END
from langchain_aws import ChatBedrockConverse
from dotenv import load_dotenv
load_dotenv()

from .prompts import INTAKE_SYSTEM_PROMPT, INTAKE_EXAMPLES

MAX_CLARIFY_TURNS = 3

# Nova Micro — text-only, lowest latency/cost tier. Right fit for pure
# extraction with no judgment call involved. Confirm the model ID and
# region in your Bedrock console (Model access) before running — Nova
# availability and generation (Nova vs Nova 2) varies by account/region.
_intake_llm = ChatBedrockConverse(
    model_id=os.getenv("BEDROCK_INTAKE_MODEL_ID", "amazon.nova-micro-v1:0"),
    region_name=os.getenv("AWS_REGION", "us-east-1"),
)


# ── State ────────────────────────────────────────────────────────────

class CheckinState(TypedDict, total=False):
    user_id: str
    country_code: str
    raw_description: str

    channel: Optional[str]
    requested_info: Optional[str]
    urgency_flag: Optional[bool]
    secrecy_flag: Optional[bool]

    clarify_turns: int
    pending_question: Optional[str]
    user_answer: Optional[str]

    matched_rule_ids: list[str]
    matched_category: Optional[str]
    retrieval_confidence: float

    risk_level: Literal["low", "medium", "high"]
    verdict_text: str

    teach_back_question: str
    user_explanation: Optional[str]

    grade_result: Literal["correct", "partial", "off_track"]
    grade_feedback: str


# ── Nodes ────────────────────────────────────────────────────────────

def intake(state: CheckinState) -> CheckinState:
    """Parse raw_description into structured fields via Claude."""
    few_shot = "\n\n".join(
        f"Input: {ex['input']}\nOutput: {json.dumps(ex['output'])}"
        for ex in INTAKE_EXAMPLES
    )

    prompt = (
        f"{INTAKE_SYSTEM_PROMPT}\n\n"
        f"Examples:\n{few_shot}\n\n"
        f"Now extract from this input:\n{state['raw_description']}"
    )

    response = _intake_llm.invoke(prompt)

    try:
        parsed = json.loads(response.content)
    except (json.JSONDecodeError, TypeError):
        # Fail safe: if extraction breaks, don't crash the flow —
        # fall through with everything unknown, clarify will fill gaps.
        parsed = {
            "channel": "unknown",
            "requested_info": None,
            "urgency_flag": None,
            "secrecy_flag": None,
        }

    state["channel"] = parsed.get("channel", "unknown")
    state["requested_info"] = parsed.get("requested_info")
    state["urgency_flag"] = parsed.get("urgency_flag")
    state["secrecy_flag"] = parsed.get("secrecy_flag")
    state["clarify_turns"] = 0
    return state


def clarify(state: CheckinState) -> CheckinState:
    """Ask one targeted question if a key field is still missing.
    TODO: clarify prompt — next up after intake.
    """
    state["clarify_turns"] = state.get("clarify_turns", 0) + 1
    return state


def should_continue_clarifying(state: CheckinState) -> str:
    have_enough_signal = (
        state.get("requested_info") is not None
        and state.get("urgency_flag") is not None
    )
    if have_enough_signal or state["clarify_turns"] >= MAX_CLARIFY_TURNS:
        return "retrieve"
    return "clarify"


def retrieve(state: CheckinState) -> CheckinState:
    """TODO: RAG lookup against the country-scoped rules dictionary."""
    return state


def classify(state: CheckinState) -> CheckinState:
    """TODO: conservative-by-default risk classification."""
    return state


def verdict(state: CheckinState) -> CheckinState:
    """TODO: plain-language, voice-read verdict."""
    return state


def teach_back(state: CheckinState) -> CheckinState:
    state["teach_back_question"] = "In your own words, why was this risky?"
    return state


def grade(state: CheckinState) -> CheckinState:
    """TODO: grade the user's explanation against the matched rule."""
    return state


# ── Graph assembly ───────────────────────────────────────────────────

def build_checkin_graph():
    graph = StateGraph(CheckinState)

    graph.add_node("intake", intake)
    graph.add_node("clarify", clarify)
    graph.add_node("retrieve", retrieve)
    graph.add_node("classify", classify)
    graph.add_node("verdict", verdict)
    graph.add_node("teach_back", teach_back)
    graph.add_node("grade", grade)

    graph.set_entry_point("intake")
    graph.add_edge("intake", "clarify")
    graph.add_conditional_edges(
        "clarify",
        should_continue_clarifying,
        {"clarify": "clarify", "retrieve": "retrieve"},
    )
    graph.add_edge("retrieve", "classify")
    graph.add_edge("classify", "verdict")
    graph.add_edge("verdict", "teach_back")
    graph.add_edge("teach_back", "grade")
    graph.add_edge("grade", END)

    return graph.compile()


checkin_graph = build_checkin_graph()