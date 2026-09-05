"""
Aegis — quick manual pipeline test.

Runs intake -> retrieve -> classify -> verdict directly (skipping
clarify/teach_back, which pause on interrupt() and need a real
conversational loop, not a one-shot script).

Test scenarios are kept SEPARATE from the few-shot INTAKE_EXAMPLES in
prompts.py on purpose: testing against the same inputs the extractor was
taught with only proves it memorised them. These scenarios include cases
the model was NOT shown, especially the "manipulation signal, no rule
match" path.

Usage: python3 -m scripts.test_pipeline
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.graphs.checkin import intake, retrieve, classify, verdict


# Raw inputs only — no expected output. The point is to see what the
# pipeline produces, not to assert extraction (that's the extractor's job).
TEST_SCENARIOS = [
    # 1. Digital arrest — should match in-006, high (rule + combo)
    (
        "ek call aaya tha, bola mera sim block hoga, kuch illegal activity "
        "hua hai mere aadhar pe, phir usne bola ek officer se baat karo, "
        "aur bola call mat kaato jab tak police station nahi pahunch jaate"
    ),
    # 2. Lottery SMS — should match in-002, medium
    "just got a message saying I won a lottery, need to pay fee to claim it",
    # 3. OLX UPI PIN — should match in-003, high (sensitive ask)
    (
        "maine olx pe apna purana phone becha tha, ek aadmi ne bola wo buyer "
        "hai, usne mujhe ek link bheja upi pe request collect karne ke liye "
        "aur bola apna pin daal do payment receive karne ke liye, thoda jaldi "
        "bhi kar raha tha bola dusra buyer bhi wait kar raha hai"
    ),
    # 4. Calm sister payment — no match, low
    (
        "meri behen ne mujhe paise bheje the birthday ke liye, google pay se, "
        "usne bas bola ki UPI ID check kar lena sahi hai ya nahi, koi jaldi "
        "nahi thi, aaram se baat hui"
    ),
    # 5. Calm bank card-number call — should match in-001, high (sensitive ask)
    (
        "bank se call tha bole aapka credit card verify karna hai, maine unse "
        "card number bola, unhone koi jaldi nahi ki, bole jab time mile tab "
        "batana, aur maine apni wife ko bhi turant bata diya baad mein"
    ),
    # 6. NEW — emergency-impersonation scam. Heavy urgency + secrecy, but NO
    #    rule in the dictionary and NO sensitive-info keyword ("paise", not
    #    OTP/PIN/card). This is the ONLY case that exercises the high_no_match
    #    path: expect matched_rule_ids [], confidence < 0.35, risk_level high,
    #    and the honest no-match verdict (not a crash, not an empty {rule}).
    (
        "abhi ek call aaya, bola aapke bete ka accident ho gaya hai hospital "
        "mein hai, abhi turant paise bhejo warna operation nahi hoga, aur kisi "
        "ko mat batao na apni wife ko na police ko, bas mujhse baat karo"
    ),
]


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
    for i, scenario in enumerate(TEST_SCENARIOS):
        run_example(i, scenario)