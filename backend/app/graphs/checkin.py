"""
Aegis — Check-in + Teach-back LangGraph
"""

import json
import os
from typing import TypedDict, Optional, Literal

from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver
from langgraph.types import interrupt
from langchain_aws import ChatBedrockConverse
from dotenv import load_dotenv
load_dotenv()

from .prompts import (
    INTAKE_SYSTEM_PROMPT, INTAKE_EXAMPLES, CLARIFY_QUESTIONS,
    VERDICT_TEMPLATES, REPORTING_SUFFIX, GRADE_SYSTEM_PROMPT,
)
from ..rag.store import query_rules, get_by_category

MAX_CLARIFY_TURNS = 3

SENSITIVE_INFO_KEYWORDS = [
    "otp", "pin", "cvv", "password", "aadhaar", "card number", "kyc",
]


_intake_llm = ChatBedrockConverse(
    model_id=os.getenv("BEDROCK_INTAKE_MODEL_ID", "amazon.nova-micro-v1:0"),
    region_name=os.getenv("AWS_REGION", "us-east-1"),
)

_grade_llm = ChatBedrockConverse(
    model_id=os.getenv("BEDROCK_GRADE_MODEL_ID", "amazon.nova-micro-v1:0"),
    region_name=os.getenv("AWS_REGION", "us-east-1"),
)


class CheckinState(TypedDict, total=False):
    user_id: str
    country_code: str
    language: str  # "en" | "hi" — drives question templates + verdict copy
    raw_description: str
    conversation_log: list[str]

    channel: Optional[str]
    requested_info: Optional[str]
    urgency_flag: Optional[bool]
    secrecy_flag: Optional[bool]

    clarify_turns: int

    matched_rule_ids: list[str]
    matched_category: Optional[str]
    matched_rule_text: Optional[str]
    matched_source: Optional[str]
    matched_source_url: Optional[str]
    retrieval_confidence: float

    risk_level: Literal["low", "medium", "high"]
    risk_reasons: list[str]
    verdict_text: str

    teach_back_question: str
    user_explanation: Optional[str]

    grade_result: Literal["correct", "partial", "off_track"]
    grade_feedback: str


def _extract_fields(text: str) -> dict:
    """Shared extraction call — used by intake and by clarify's re-run."""
    few_shot = "\n\n".join(
        f"Input: {ex['input']}\nOutput: {json.dumps(ex['output'])}"
        for ex in INTAKE_EXAMPLES
    )
    prompt = (
        f"{INTAKE_SYSTEM_PROMPT}\n\nExamples:\n{few_shot}\n\n"
        f"Now extract from this input:\n{text}"
    )
    response = _intake_llm.invoke(prompt)
    try:
        return json.loads(response.content)
    except (json.JSONDecodeError, TypeError):
        return {}


def _build_retrieval_query(state: CheckinState) -> str:
    """Turn extracted signals + raw description into a query that reads
    like the dictionary's red_flag_context entries, since embedding
    similarity works best when query and target share a register."""
    parts = []
    if state.get("channel") and state["channel"] != "unknown":
        parts.append(f"Contact happened via {state['channel'].replace('_', ' ')}.")
    if state.get("requested_info"):
        parts.append(f"They asked for {state['requested_info']}.")
    if state.get("urgency_flag"):
        parts.append("There was urgency or a threat to act quickly.")
    if state.get("secrecy_flag"):
        parts.append("The user was told to keep it secret or not verify with anyone else.")
    parts.append(state.get("raw_description", ""))
    return " ".join(parts).strip()


def intake(state: CheckinState) -> CheckinState:
    parsed = _extract_fields(state["raw_description"])
    state["channel"] = parsed.get("channel", "unknown")
    state["requested_info"] = parsed.get("requested_info")
    state["urgency_flag"] = parsed.get("urgency_flag")
    state["secrecy_flag"] = parsed.get("secrecy_flag")
    state["clarify_turns"] = 0
    state["conversation_log"] = [f"User: {state['raw_description']}"]
    return state


def clarify(state: CheckinState) -> CheckinState:
    """Ask one targeted question about whichever key field is still
    missing, pause for the answer via interrupt(), then re-run
    extraction over the accumulated transcript and fill only the
    fields that were still null."""
    lang = state.get("language", "en")

    if state.get("requested_info") is None:
        field, question = "requested_info", CLARIFY_QUESTIONS["requested_info"][lang]
    else:
        field, question = "urgency_flag", CLARIFY_QUESTIONS["urgency_flag"][lang]

    answer = interrupt({"question": question, "field": field})

    log = state.get("conversation_log", [])
    log.append(f"Aegis: {question}")
    log.append(f"User: {answer}")
    state["conversation_log"] = log
    state["clarify_turns"] = state.get("clarify_turns", 0) + 1

    extracted = _extract_fields("\n".join(log))
    for f in ("channel", "requested_info", "urgency_flag", "secrecy_flag"):
        if state.get(f) is None and extracted.get(f) is not None:
            state[f] = extracted[f]

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
    query_text = _build_retrieval_query(state)
    matches = query_rules(
        query_text=query_text,
        country_code=state.get("country_code", "IN"),
    )

    state["matched_rule_ids"] = [m["id"] for m in matches]
    top = matches[0] if matches else None
    state["matched_category"] = top["category"] if top else None
    state["matched_rule_text"] = top["rule"] if top else None
    state["matched_source"] = top["source"] if top else None
    state["matched_source_url"] = top["source_url"] if top else None
    state["retrieval_confidence"] = top["similarity"] if top else 0.0
    return state


def classify(state: CheckinState) -> CheckinState:
    """Deterministic, conservative-by-default risk classification.
    No LLM call — a rule matched or a dangerous pattern present is
    never downgraded by a model's judgment call.

    Priority ladder (top wins):
      1. rule match + (sensitive ask OR urgency+secrecy)  -> high  (verdict quotes rule)
      2. sensitive ask OR urgency+secrecy, no rule match  -> high  (verdict: no-match template)
      3. rule match alone                                 -> medium
      4. a single urgency/secrecy flag alone              -> medium
      5. none of the above                                -> low

    Rationale for #2 sitting ABOVE #3: a scam we can't name but can feel
    (active pressure + isolation, or a request for secrets) is more dangerous
    than a named pattern with no active manipulation. Rule coverage always
    lags real scams, so the unmatched-but-manipulative path is the net for
    novel scams and for retrieval misses on scams that ARE in the dictionary.
    A false 'high' costs the user a minute of verifying; a false 'medium' on a
    real scam can cost them everything — so we err toward the cheap mistake."""
    reasons = []

    requested = (state.get("requested_info") or "").lower()
    sensitive_ask = any(kw in requested for kw in SENSITIVE_INFO_KEYWORDS)
    if sensitive_ask:
        reasons.append(f"requested_info matched sensitive pattern: '{requested}'")

    combo_pattern = state.get("urgency_flag") is True and state.get("secrecy_flag") is True
    if combo_pattern:
        reasons.append("urgency + secrecy both present (isolation tactic)")

    has_match = bool(state.get("matched_rule_ids"))
    if has_match:
        reasons.append(
            f"matched rule(s): {state['matched_rule_ids']} "
            f"(category: {state.get('matched_category')})"
        )

    if has_match and (sensitive_ask or combo_pattern):
        risk_level = "high"
    elif sensitive_ask or combo_pattern:
        # Strong manipulation signal with no rule match — ranks above "rule
        # alone" below. Verdict uses the grounded no-match template.
        risk_level = "high"
        reasons.append("high risk on manipulation signal alone (no specific rule matched)")
    elif has_match:
        risk_level = "medium"
    elif state.get("urgency_flag") or state.get("secrecy_flag"):
        risk_level = "medium"
        reasons.append("single pressure/secrecy signal present without a rule match")
    else:
        risk_level = "low"
        reasons.append("no rule match, no sensitive request, no urgency/secrecy detected")

    state["risk_level"] = risk_level
    state["risk_reasons"] = reasons
    return state


def verdict(state: CheckinState) -> CheckinState:
    """Build the spoken verdict from fixed templates — never
    free-generated, so it can't state anything ungrounded."""
    lang = state.get("language", "en")
    country_code = state.get("country_code", "IN")
    risk_level = state["risk_level"]

    if risk_level == "high":
        reporting = REPORTING_SUFFIX[lang]
        rule_text = state.get("matched_rule_text")
        if rule_text:
            # A specific rule matched — quote it.
            state["verdict_text"] = VERDICT_TEMPLATES["high"][lang].format(
                rule=rule_text, reporting=reporting
            )
        else:
            # High risk on manipulation signal alone — no rule to quote.
            # Honest language ("I don't recognise this as one specific scam...")
            # so we never claim a match we don't have, while still driving the
            # protective behaviour and appending the reporting line.
            state["verdict_text"] = VERDICT_TEMPLATES["high_no_match"][lang].format(
                reporting=reporting
            )

    elif risk_level == "medium":
        rule_text = state.get("matched_rule_text")
        if rule_text:
            rule_suffix = (
                f" For example: {rule_text}" if lang == "en"
                else f" उदाहरण के लिए: {rule_text}"
            )
        else:
            rule_suffix = ""
        state["verdict_text"] = VERDICT_TEMPLATES["medium"][lang].format(
            rule_suffix=rule_suffix
        )

    else:  # low
        state["verdict_text"] = VERDICT_TEMPLATES["low"][lang]

    return state


def teach_back(state: CheckinState) -> CheckinState:
    """Ask the teach-back question and pause for the user's own
    explanation — same interrupt pattern as clarify."""
    question = "In your own words, why was this risky?"
    state["teach_back_question"] = question
    answer = interrupt({"question": question, "field": "user_explanation"})
    state["user_explanation"] = answer
    return state


def grade(state: CheckinState) -> CheckinState:
    """Grade the user's teach-back explanation against the matched rule
    (or, if no rule matched, against the manipulation principle that made
    it high risk).

    This is the ONLY node that uses an LLM to make a JUDGMENT — because
    "did this explanation show understanding?" is open-ended language and
    can't be done with if/else like classify. It is fenced in so it stays
    grounded: it grades ONLY against the reference below, adds no new scam
    facts, and fails safe to a neutral 'partial' if the model returns junk
    (so it never falsely praises the user and never crashes the check-in)."""
    lang = state.get("language", "en")
    explanation = (state.get("user_explanation") or "").strip()

    # (A) Nothing to grade: it wasn't risky (low), or the user said nothing.
    #     Exit gracefully — don't send an empty question to the LLM.
    if state.get("risk_level") == "low" or not explanation:
        state["grade_result"] = "partial"
        state["grade_feedback"] = (
            "No problem — the main thing is to pause and check whenever "
            "something feels off."
            if lang == "en" else
            "कोई बात नहीं — सबसे ज़रूरी बात यही है कि जब भी कुछ अजीब लगे, रुककर जाँच लें।"
        )
        return state

    # (B) Pick the answer key. If a rule matched, that's the reference.
    #     If NOT (the high_no_match case, e.g. the emergency scam), grade
    #     against the manipulation principle that triggered the flag.
    reference = state.get("matched_rule_text")
    if not reference:
        reference = (
            "The real danger was the combination of pressure to act "
            "immediately and being told to keep it secret or not check with "
            "anyone — that isolation is how scams stop people thinking clearly."
        )

    # (C) Ask the LLM to judge the explanation against the reference only.
    language_name = "Hindi" if lang == "hi" else "English"
    prompt = GRADE_SYSTEM_PROMPT.format(
        reference=reference,
        explanation=explanation,
        language_name=language_name,
    )
    try:
        response = _grade_llm.invoke(prompt)
        parsed = json.loads(response.content)
        result = parsed.get("grade_result")
        feedback = (parsed.get("grade_feedback") or "").strip()
        if result not in ("correct", "partial", "off_track") or not feedback:
            raise ValueError("grade output missing/invalid fields")
    except (json.JSONDecodeError, TypeError, ValueError):
        # (D) Model failed or returned junk. Never crash, never falsely
        #     praise. Fall back to neutral 'partial' and re-teach the point.
        result = "partial"
        feedback = (
            f"The key thing to remember: {reference}"
            if lang == "en" else
            f"याद रखने वाली मुख्य बात: {reference}"
        )

    state["grade_result"] = result
    state["grade_feedback"] = feedback
    return state


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

    checkpointer = MemorySaver()
    return graph.compile(checkpointer=checkpointer)


checkin_graph = build_checkin_graph()