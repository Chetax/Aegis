"""Aegis — rules & regulations dictionary API. Read-only, sourced content
only — this endpoint never generates or alters rule text, it just serves
the JSON as-is. Fails soft: if no matching dictionary file is found, return
an empty entries list with error:true rather than a 500, matching the
fail-safe pattern used elsewhere in this app (stats.py, tts.py).

Note: dictionary files are named by country NAME (e.g.
`rules_dictionary_india.json`), not by ISO country_code — same as
`ingest_rules.py` (session 2). So we glob every `rules_dictionary_*.json`
sibling file and match on the `country_code` field *inside* each file,
rather than guessing the filename from the code.
"""
from __future__ import annotations

import glob
import json
import os

from fastapi import APIRouter

router = APIRouter(prefix="/rules", tags=["rules"])

# Aegis/data/ is a sibling of backend/ — same path quirk noted in
# ingest_rules.py (session 2) and git commands (session 3). Resolve
# relative to THIS file's location so it works regardless of cwd.
_DATA_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "data"
)
_DATA_GLOB = os.path.join(_DATA_DIR, "rules_dictionary_*.json")


def _empty_response(country_code: str) -> dict:
    return {
        "country_name": country_code,
        "emergency_contacts": {},
        "entries": [],
        "universal_fallback_patterns": [],
        "error": True,
    }


@router.get("/dictionary")
def get_dictionary(country_code: str = "IN"):
    try:
        for path in glob.glob(_DATA_GLOB):
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            if data.get("country_code", "").upper() == country_code.upper():
                return {
                    "country_name": data.get("country_name", country_code),
                    "emergency_contacts": data.get("emergency_contacts", {}),
                    "entries": data.get("entries", []),
                    "universal_fallback_patterns": data.get(
                        "universal_fallback_patterns", {}
                    ).get("patterns", []),
                }
        # No file matched this country_code.
        print(f"[rules] no dictionary file found for country_code={country_code}")
        return _empty_response(country_code)
    except Exception as e:
        print(f"[rules] get_dictionary failed: {e}")
        return _empty_response(country_code)