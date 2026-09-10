"""
Daily story generator. Picks a rule deterministically by day-of-year,
asks Bedrock to write a short scam story broken into scenes, plus red flags
and one quiz question. Grounded in the matched rule; safe fallback if the
model fails.
"""
from __future__ import annotations

import json
import os
from datetime import date
from typing import Any

from langchain_aws import ChatBedrock

from app.rag.store import get_collection

_STORY_MODEL_ID = os.getenv(
    "BEDROCK_STORY_MODEL_ID", "us.amazon.nova-micro-v1:0"
)

_story_llm = ChatBedrock(
    model_id=_STORY_MODEL_ID,
    model_kwargs={"temperature": 0.7, "max_tokens": 1200},
)


STORY_SYSTEM_PROMPT = """You are writing a short educational story for an
elderly audience learning to recognize scams. The story is FICTIONAL but
must accurately illustrate the real scam pattern provided.

STRICT RULES:
- Do NOT name real people, real officials, or real institutions in ways
  that could defame them. Use generic titles ("a caller claiming to be
  from the police", not "Officer Sharma from Delhi Police").
- Do NOT include any operational how-to detail a scammer could reuse
  (exact scripts, specific fake documents, technical bypass instructions).
- The story teaches PATTERN RECOGNITION only — what the scam LOOKS like
  from the victim's side, not how it's executed.
- Keep language simple, warm, respectful. Never condescending.
- The victim should be portrayed with dignity — this could happen to
  anyone, not just "gullible" people.

OUTPUT FORMAT: Return ONLY valid JSON, no prose before or after:
{
  "title": "Short title, 6-10 words, engaging",
  "scenes": [
    {"icon": "phone|alert|money|shield|person|document",
     "text": "1-2 sentences narrating this beat of the story"},
    {"icon": "...", "text": "..."},
    {"icon": "...", "text": "..."},
    {"icon": "...", "text": "..."}
  ],
  "red_flags": [
    {"flag": "Short label (3-5 words)",
     "explanation": "One sentence on why this is suspicious."},
    {"flag": "...", "explanation": "..."},
    {"flag": "...", "explanation": "..."}
  ],
  "quiz": {
    "question": "Which of these is ALSO a scam warning sign?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correct_index": 0,
    "explanation": "One sentence on why the correct answer is a red flag."
  }
}

Exactly 4 scenes. Exactly 3 red flags. Exactly 4 quiz options.
Icons MUST be from: phone, alert, money, shield, person, document."""


def _fallback_story(rule: dict[str, Any]) -> dict[str, Any]:
    """Bundled story if Bedrock fails — never a broken screen."""
    return {
        "title": "The Call That Almost Cost Everything",
        "rule_id": rule.get("id", "unknown"),
        "category": rule.get("category", "scam"),
        "scenes": [
            {"icon": "phone",
             "text": "The phone rang at 2pm on a Tuesday. The caller "
                     "said he was from the police."},
            {"icon": "alert",
             "text": "He said there was a serious case, and I needed to "
                     "stay on the call — I couldn't tell anyone."},
            {"icon": "money",
             "text": "To 'clear my name', I had to transfer money to a "
                     "'safe government account' immediately."},
            {"icon": "shield",
             "text": "I hung up and called 1930. Real police never work "
                     "this way. My savings were safe."},
        ],
        "red_flags": [
            {"flag": "Impersonating authority",
             "explanation": "Real officials identify themselves in "
                            "writing and never handle cases by phone."},
            {"flag": "Demanding secrecy",
             "explanation": "'Don't tell anyone' is a scammer's shield "
                            "against you getting a second opinion."},
            {"flag": "Urgent money transfer",
             "explanation": "No genuine government process requires "
                            "immediate wire transfers to 'clear' cases."},
        ],
        "quiz": {
            "question": "Which of these is ALSO a scam warning sign?",
            "options": [
                "A bank asking you to visit a branch to verify ID",
                "A caller asking for your OTP to 'confirm your identity'",
                "An email confirming a purchase you made",
                "A doctor's office reminding you of an appointment",
            ],
            "correct_index": 1,
            "explanation": "No legitimate institution EVER asks for your "
                           "OTP — it exists precisely so only you can "
                           "authorize actions.",
        },
    }


def _pick_rule_for_today(country_code: str = "IN") -> dict[str, Any] | None:
    """Deterministic daily rotation — same rule all day, new tomorrow."""
    coll = get_collection()
    all_data = coll.get(include=["metadatas", "documents"])
    metadatas = all_data.get("metadatas", []) or []
    documents = all_data.get("documents", []) or []

    country_rules = [
        (m, d) for m, d in zip(metadatas, documents)
        if m.get("country_code") == country_code
    ]
    if not country_rules:
        return None

    day_of_year = date.today().timetuple().tm_yday
    idx = day_of_year % len(country_rules)
    meta, doc = country_rules[idx]
    return {
        "id": meta.get("rule_id"),
        "category": meta.get("category"),
        "rule_text": doc,
        "source": meta.get("source"),
        "source_url": meta.get("source_url"),
    }


def generate_daily_story(country_code: str = "IN") -> dict[str, Any]:
    """Main entry point. Returns a full story payload."""
    rule = _pick_rule_for_today(country_code)
    if rule is None:
        return _fallback_story({"id": "fallback", "category": "general"})

    user_prompt = (
        f"Scam pattern to illustrate (category: {rule['category']}):\n\n"
        f"{rule['rule_text']}\n\n"
        f"Write a short story showing an ordinary person encountering "
        f"this scam and recognizing it in time. Follow the JSON format "
        f"exactly."
    )

    try:
        resp = _story_llm.invoke(
            [
                ("system", STORY_SYSTEM_PROMPT),
                ("user", user_prompt),
            ]
        )
        raw = resp.content if isinstance(resp.content, str) else str(resp.content)
        # Model sometimes wraps in ```json ... ``` — strip if present.
        raw = raw.strip()
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
            raw = raw.strip()

        parsed = json.loads(raw)

        # Attach rule metadata for the client.
        parsed["rule_id"] = rule["id"]
        parsed["category"] = rule["category"]
        parsed["source"] = rule.get("source")
        parsed["source_url"] = rule.get("source_url")
        return parsed
    except Exception as e:
        print(f"[story] Bedrock generation failed, using fallback: {e}")
        fb = _fallback_story(rule)
        fb["source"] = rule.get("source")
        fb["source_url"] = rule.get("source_url")
        return fb