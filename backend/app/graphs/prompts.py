"""
Aegis — Check-in graph prompts.

Each prompt is designed for a specific node in checkin.py. Kept separate
from graph wiring so prompt iteration doesn't touch graph logic.
"""

INTAKE_SYSTEM_PROMPT = """You are the intake step of a scam-safety check-in tool. \
A user has just described, out loud, something that happened to them — often \
transcribed from Hindi-English mixed speech (Hinglish), sometimes rambling or \
out of order, sometimes anxious or unclear.

Your job is ONLY to extract structured facts. Do not judge whether it's a scam. \
Do not add advice. Do not invent details that weren't said or clearly implied.

Extract these fields:

- channel: how the OTHER PERSON communicated with the user. One of: "call", \
"sms", "whatsapp", "email", "marketplace_chat", "in_person", "unknown". Use \
"marketplace_chat" for OLX/Facebook Marketplace/Quikr-style buyer-seller \
interactions, even if a link was later shared. Use "in_person" ONLY if the \
user describes a physical face-to-face interaction — selling an item online \
is NOT in_person, even if the item itself changes hands later. Use "unknown" \
if not stated or unclear.

- requested_info: what the other person asked for, in a short phrase. Be \
SPECIFIC about the type of PIN/code when mentioned — "UPI PIN" and "bank \
card PIN" are different things with different risk implications; do not \
default to "bank PIN" unless a bank card is explicitly mentioned. Other \
examples: "OTP", "Aadhaar number", "money transfer". Use null if nothing \
was asked for, or if it hasn't come up yet.

- urgency_flag: true if the caller/message created time pressure or a threat \
("act now", "your account will be blocked", "another buyer is waiting", \
"you'll be arrested"). false ONLY if the user's account of the interaction is \
complete enough to tell there was clearly no pressure or threat. null if the \
description doesn't yet cover this — do not guess.

- secrecy_flag: true if the user was told to keep it secret, not hang up, not \
tell family, or not verify with anyone else. false ONLY if the user's account \
is complete enough to tell that no such instruction occurred — not merely \
because they didn't happen to mention it. null if the description doesn't yet \
cover this — do not guess.

Rules:
- Use null liberally. A missing or unclear fact should stay null, not be \
guessed, and not be false by default. false is a positive claim that the \
tactic clearly did NOT occur, not an absence of evidence.
- Preserve the user's own words for requested_info rather than paraphrasing \
into legal/technical language, but be precise about PIN/code TYPE as above.
- Output ONLY valid JSON matching this schema, nothing else — no preamble, \
no explanation, no markdown fences.

Schema:
{{
  "channel": "call" | "sms" | "whatsapp" | "email" | "marketplace_chat" | "in_person" | "unknown",
  "requested_info": string | null,
  "urgency_flag": true | false | null,
  "secrecy_flag": true | false | null
}}
"""

INTAKE_EXAMPLES = [
    {
        "input": (
            "ek call aaya tha, bola mera sim block hoga, kuch illegal activity "
            "hua hai mere aadhar pe, phir usne bola ek officer se baat karo, "
            "aur bola call mat kaato jab tak police station nahi pahunch jaate"
        ),
        "output": {
            "channel": "call",
            "requested_info": None,
            "urgency_flag": True,
            "secrecy_flag": True,
        },
    },
    {
        "input": "just got a message saying I won a lottery, need to pay fee to claim it",
        "output": {
            "channel": "sms",
            "requested_info": "processing fee payment",
            "urgency_flag": None,
            "secrecy_flag": None,
        },
    },
    {
        "input": (
            "maine olx pe apna purana phone becha tha, ek aadmi ne bola wo "
            "buyer hai, usne mujhe ek link bheja upi pe request collect "
            "karne ke liye aur bola apna pin daal do payment receive karne "
            "ke liye, thoda jaldi bhi kar raha tha bola dusra buyer bhi "
            "wait kar raha hai"
        ),
        "output": {
            "channel": "marketplace_chat",
            "requested_info": "UPI PIN",
            "urgency_flag": True,
            "secrecy_flag": None,
        },
    },
    {
        "input": (
            "meri behen ne mujhe paise bheje the birthday ke liye, google pay "
            "se, usne bas bola ki UPI ID check kar lena sahi hai ya nahi, "
            "koi jaldi nahi thi, aaram se baat hui"
        ),
        "output": {
            "channel": "whatsapp",
            "requested_info": None,
            "urgency_flag": False,
            "secrecy_flag": False,
        },
    },
    {
        "input": (
            "bank se call tha bole aapka credit card verify karna hai, maine "
            "unse card number bola, unhone koi jaldi nahi ki, bole jab time "
            "mile tab batana, aur maine apni wife ko bhi turant bata diya "
            "baad mein"
        ),
        "output": {
            "channel": "call",
            "requested_info": "credit card number",
            "urgency_flag": False,
            "secrecy_flag": False,
        },
    },
]

CLARIFY_QUESTIONS = {
    "requested_info": {
        "en": "What exactly did they ask you for — money, a code, or some information?",
        "hi": "Unhone aapse exactly kya manga — paise, koi code, ya koi jaankari?",
    },
    "urgency_flag": {
        "en": "Did they pressure you to act quickly, or threaten something bad would happen?",
        "hi": "Kya unhone jaldi karne ke liye kaha, ya koi dhamki di?",
    },
}

VERDICT_TEMPLATES = {
    "high": {
        "en": "This matches a known scam pattern: {rule} My advice — do not do what they're asking. {reporting}",
        "hi": "यह एक जाने-पहचाने स्कैम पैटर्न जैसा लगता है: {rule} मेरी सलाह — जो वो मांग रहे हैं वो मत करें। {reporting}",
    },
    "medium": {
        "en": "I'm not fully sure, but this has some warning signs.{rule_suffix} Please pause before doing anything. If in doubt, call back using the number on your card or bank statement — never a number the caller gave you.",
        "hi": "मुझे पूरा यकीन नहीं है, लेकिन इसमें कुछ चेतावनी के संकेत हैं।{rule_suffix} कृपया कुछ भी करने से पहले रुकें। अगर शक हो, तो अपने कार्ड या बैंक स्टेटमेंट पर लिखे नंबर से वापस कॉल करें — कॉल करने वाले के दिए नंबर से नहीं।",
    },
    "low": {
        "en": "Based on what you've told me, I don't see a clear warning sign. But if anything feels off, it's fine to pause and check with your bank or a family member before doing anything.",
        "hi": "आपने जो बताया उसके आधार पर, मुझे कोई साफ चेतावनी का संकेत नहीं दिखा। लेकिन अगर कुछ भी अजीब लगे, तो कुछ भी करने से पहले रुकना और अपने बैंक या परिवार के किसी सदस्य से पूछना ठीक रहेगा।",
    },
}

REPORTING_SUFFIX = {
    "en": "If you've already shared something you shouldn't have, report it now: call 1930 or visit cybercrime.gov.in.",
    "hi": "अगर आपने पहले ही कुछ ऐसा बता दिया है जो नहीं बताना चाहिए था, तो अभी रिपोर्ट करें: 1930 पर कॉल करें या cybercrime.gov.in पर जाएं।",
}