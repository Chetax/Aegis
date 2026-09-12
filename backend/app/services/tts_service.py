"""
Aegis — Polly-backed text-to-speech. Kajal is AWS's bilingual Hindi +
Indian-English neural voice — one voice, both languages, matches the
Hinglish reality of the app's actual users.
"""
from __future__ import annotations

import hashlib
import os

import boto3

_REGION = os.getenv("AWS_REGION", "ap-south-1")
_polly = boto3.client("polly", region_name=_REGION)

_LANGUAGE_CODES = {"en": "en-IN", "hi": "hi-IN"}

# Simple in-memory cache, same spirit as story.py's daily-story cache —
# the daily story is the same text for every user all day, no reason to
# re-synthesize it per request. Bounded so a long demo session doesn't
# grow this unbounded.
_cache: dict[str, bytes] = {}
_CACHE_MAX = 200


def synthesize(text: str, language: str = "en") -> bytes:
    lang_code = _LANGUAGE_CODES.get(language, "en-IN")
    cache_key = hashlib.sha256(f"{lang_code}:{text}".encode()).hexdigest()
    if cache_key in _cache:
        return _cache[cache_key]

    resp = _polly.synthesize_speech(
        Text=text,
        OutputFormat="mp3",
        VoiceId="Kajal",
        Engine="neural",
        LanguageCode=lang_code,
    )
    audio = resp["AudioStream"].read()

    if len(_cache) >= _CACHE_MAX:
        _cache.pop(next(iter(_cache)))  # evict oldest, good enough for a demo run
    _cache[cache_key] = audio
    return audio