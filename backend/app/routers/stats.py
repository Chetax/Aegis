"""Aegis — progress/stats API. Fails soft: DynamoDB errors return zeroed
defaults with error:true rather than a 500, so a stats hiccup never blocks
anything — matches the fail-safe pattern used everywhere else in this app."""
from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

from app.services import stats_store

router = APIRouter(prefix="/stats", tags=["stats"])


class StatsEvent(BaseModel):
    device_id: str
    type: str  # "lesson" | "checkin"
    xp: int


@router.post("/event")
def post_event(evt: StatsEvent):
    try:
        totals = stats_store.record_event(evt.device_id, evt.type, evt.xp)
        return {k: totals[k] for k in ("total_xp", "current_streak", "longest_streak")}
    except Exception as e:
        print(f"[stats] record_event failed: {e}")
        return {"total_xp": 0, "current_streak": 0, "longest_streak": 0, "error": True}


@router.get("/summary")
def get_summary(device_id: str):
    try:
        totals = stats_store.get_totals(device_id)
        return {
            **{k: totals[k] for k in ("total_xp", "current_streak", "longest_streak")},
            "last_7_days": stats_store.get_last_n_days(device_id, 7),
            "month_summary": stats_store.get_month_summary(device_id),
        }
    except Exception as e:
        print(f"[stats] get_summary failed: {e}")
        return {"total_xp": 0, "current_streak": 0, "longest_streak": 0,
                 "last_7_days": [], "month_summary": {"lessons": 0, "checkins": 0, "xp": 0}, "error": True}