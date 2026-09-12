"""Aegis — TTS API. Narration is an enhancement, not a core flow: a
failure here must never break the reading/check-in experience, so this
raises a clean 502 rather than crashing anything upstream."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

from app.services import tts_service

router = APIRouter(prefix="/tts", tags=["tts"])


class TTSRequest(BaseModel):
    text: str
    language: str = "en"  # "en" | "hi"


@router.post("/synthesize")
def synthesize(req: TTSRequest):
    try:
        audio = tts_service.synthesize(req.text, req.language)
        return Response(content=audio, media_type="audio/mpeg")
    except Exception as e:
        print(f"[tts] synthesize failed: {e}")
        raise HTTPException(status_code=502, detail=f"TTS failed: {e}")