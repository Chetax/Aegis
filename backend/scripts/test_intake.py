"""
Quick standalone test — run directly to verify Nova access + intake extraction
work before wiring anything into FastAPI routes.

Usage (from backend/, with venv active):
    python -m app.graphs.test_intake
"""

from dotenv import load_dotenv
load_dotenv()

from app.graphs.checkin import intake

test_input1 = (
    "ek call aaya tha, bola mera sim block hoga, kuch illegal activity "
    "hua hai mere aadhar pe, phir usne bola ek officer se baat karo, "
    "aur bola call mat kaato jab tak police station nahi pahunch jaate"
)

test_input2 = (
    "maine olx pe apna purana phone becha tha, ek aadmi ne bola wo buyer hai "
    "aur payment karna chahta hai, usne mujhe ek link bheja upi pe request "
    "collect karne ke liye aur bola apna pin daal do payment receive karne "
    "ke liye, thoda jaldi bhi kar raha tha bola dusra buyer bhi wait kar raha hai"
)

state = {"raw_description": test_input2}
result = intake(state)

print("---")
print("Extracted fields:")
print(f"  channel:        {result.get('channel')}")
print(f"  requested_info: {result.get('requested_info')}")
print(f"  urgency_flag:   {result.get('urgency_flag')}")
print(f"  secrecy_flag:   {result.get('secrecy_flag')}")
print("---")