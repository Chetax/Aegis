"""
Aegis — quick manual test for the grade() node.

grade() can't be exercised by test_pipeline.py because that script skips the
interrupt nodes (clarify/teach_back), so user_explanation is never set. Here we
set matched_rule_text + user_explanation by hand and call grade() directly.

Usage: python3 -m scripts.test_grade
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.graphs.checkin import grade

RULE = (
    "No Indian law enforcement agency — police, CBI, ED, Customs, RBI, or the "
    "courts — ever arrests you or collects money over a phone or video call."
)

# (label, state) — first three have a matched rule; the 4th has NO rule
# (the high_no_match path); the 5th is low-risk (nothing to grade).
CASES = [
    (
        "expect correct",
        {
            "language": "en", "risk_level": "high", "matched_rule_text": RULE,
            "user_explanation": (
                "real police don't arrest you on a video call or ask for money, "
                "so it was fake and meant to scare me"
            ),
        },
    ),
    (
        "expect partial",
        {
            "language": "en", "risk_level": "high", "matched_rule_text": RULE,
            "user_explanation": "something just felt off about it",
        },
    ),
    (
        "expect off_track",
        {
            "language": "en", "risk_level": "high", "matched_rule_text": RULE,
            "user_explanation": "because my internet was slow that day",
        },
    ),
    (
        "no-rule (high_no_match) path",
        {
            "language": "en", "risk_level": "high",
            # NOTE: no matched_rule_text — grade() must fall back to the
            # manipulation-principle reference.
            "user_explanation": (
                "they rushed me and told me not to tell anyone, that pressure "
                "was the trick"
            ),
        },
    ),
    (
        "low risk (nothing to grade)",
        {
            "language": "en", "risk_level": "low",
            "user_explanation": "it was just my sister sending a birthday gift",
        },
    ),
]


if __name__ == "__main__":
    for label, state in CASES:
        out = grade(dict(state))
        print(f"[{label}]")
        print("  grade_result:  ", out.get("grade_result"))
        print("  grade_feedback:", out.get("grade_feedback"))
        print()