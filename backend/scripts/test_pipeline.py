"""
Aegis — quick manual pipeline test.

Runs intake -> retrieve -> classify -> verdict directly (skipping
clarify/teach_back, which pause on interrupt() and need a real
conversational loop, not a one-shot script) against the existing
few-shot examples in prompts.py.

Usage: python3 -m scripts.test_pipeline
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.graphs.checkin import intake, retrieve, classify, verdict
from app.graphs.prompts import INTAKE_EXAMPLES


def run_example(i: int, raw_description: str):
    state = {
        "raw_description": raw_description,
        "country_code": "IN",
        "language": "en",
    }
    state = intake(state)
    state = retrieve(state)
    state = classify(state)
    state = verdict(state)

    print(f"--- Example {i + 1} ---")
    print(f"input: {raw_description[:90]}...")
    print("extracted:", {
        k: state.get(k)
        for k in ("channel", "requested_info", "urgency_flag", "secrecy_flag")
    })
    print("matched_rule_ids:", state.get("matched_rule_ids"))
    print("retrieval_confidence:", state.get("retrieval_confidence"))
    print("risk_level:", state.get("risk_level"))
    print("risk_reasons:", state.get("risk_reasons"))
    print("verdict_text:", state.get("verdict_text"))
    print()


if __name__ == "__main__":
    for i, ex in enumerate(INTAKE_EXAMPLES):
        run_example(i, ex["input"])