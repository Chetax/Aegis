from fastapi import APIRouter
from app.graphs.story import get_daily_story

router = APIRouter()


@router.get("/story/daily")
async def daily_story(country_code: str = "IN"):
    """Returns today's story. Same content all day, new tomorrow."""
    return get_daily_story(country_code=country_code)