"""
Aegis — DynamoDB-backed progress store (XP, streaks, daily activity).

Mirrors the shape of the Flutter-side ProgressService exactly: one
aggregate "TOTALS" record per device (xp, streak, longest_streak,
last_active_date) plus one "DAY#<date>" record per day-with-activity
(lessons, checkins, xp) for the weekly/monthly breakdown.
"""
from __future__ import annotations

import os
from datetime import date, timedelta
from typing import Any

import boto3
from boto3.dynamodb.conditions import Key

_TABLE_NAME = os.getenv("AEGIS_STATS_TABLE", "aegis_progress")
_REGION = os.getenv("AWS_REGION", "ap-south-1")
_DYNAMODB_ENDPOINT = os.getenv("AEGIS_DYNAMODB_ENDPOINT")

if _DYNAMODB_ENDPOINT:
    _dynamodb = boto3.resource(
        "dynamodb",
        region_name="localhost",
        endpoint_url=_DYNAMODB_ENDPOINT,
        aws_access_key_id="local",
        aws_secret_access_key="local",
    )
else:
    _dynamodb = boto3.resource("dynamodb", region_name=_REGION)

_table = None


def _ensure_table():
    existing = [t.name for t in _dynamodb.tables.all()]
    if _TABLE_NAME in existing:
        return
    table = _dynamodb.create_table(
        TableName=_TABLE_NAME,
        KeySchema=[
            {"AttributeName": "pk", "KeyType": "HASH"},
            {"AttributeName": "sk", "KeyType": "RANGE"},
        ],
        AttributeDefinitions=[
            {"AttributeName": "pk", "AttributeType": "S"},
            {"AttributeName": "sk", "AttributeType": "S"},
        ],
        BillingMode="PAY_PER_REQUEST",
    )
    table.wait_until_exists()


def _get_table():
    global _table
    if _table is None:
        _ensure_table()
        _table = _dynamodb.Table(_TABLE_NAME)
    return _table


def _pk(device_id: str) -> str:
    return f"USER#{device_id}"


def _date_key(d: date) -> str:
    return d.isoformat()


def get_totals(device_id: str) -> dict[str, Any]:
    resp = _get_table().get_item(Key={"pk": _pk(device_id), "sk": "TOTALS"})
    item = resp.get("Item")
    if item is None:
        return {"total_xp": 0, "current_streak": 0, "longest_streak": 0, "last_active_date": None}
    return {
        "total_xp": int(item.get("total_xp", 0)),
        "current_streak": int(item.get("current_streak", 0)),
        "longest_streak": int(item.get("longest_streak", 0)),
        "last_active_date": item.get("last_active_date"),
    }


def _put_totals(device_id: str, totals: dict[str, Any]) -> None:
    _get_table().put_item(Item={"pk": _pk(device_id), "sk": "TOTALS", **totals})


def _bump_day(device_id: str, day: date, xp: int, lesson: bool, checkin: bool) -> None:
    sk = f"DAY#{_date_key(day)}"
    expr = "ADD xp :xp"
    values = {":xp": xp}
    if lesson:
        expr += ", lessons :one"
        values[":one"] = 1
    if checkin:
        expr += ", checkins :one2"
        values[":one2"] = 1
    _get_table().update_item(
        Key={"pk": _pk(device_id), "sk": sk},
        UpdateExpression=expr,
        ExpressionAttributeValues=values,
    )


def record_event(device_id: str, event_type: str, xp: int) -> dict[str, Any]:
    """Lessons are gated to once per calendar day (streak logic, matches
    the client's completedToday() guard). Check-ins always add XP."""
    today = date.today()
    totals = get_totals(device_id)
    already_today = totals["last_active_date"] == _date_key(today)

    if event_type == "lesson" and not already_today:
        totals["total_xp"] += xp
        last = totals["last_active_date"]
        if last is not None:
            yesterday = _date_key(today - timedelta(days=1))
            totals["current_streak"] = totals["current_streak"] + 1 if last == yesterday else 1
        else:
            totals["current_streak"] = 1
        totals["longest_streak"] = max(totals["longest_streak"], totals["current_streak"])
        totals["last_active_date"] = _date_key(today)
        _put_totals(device_id, totals)
        _bump_day(device_id, today, xp, lesson=True, checkin=False)
    elif event_type == "checkin":
        totals["total_xp"] += xp
        _put_totals(device_id, totals)
        _bump_day(device_id, today, xp, lesson=False, checkin=True)

    return totals


def get_last_n_days(device_id: str, n: int = 7) -> list[dict[str, Any]]:
    today = date.today()
    start = today - timedelta(days=n - 1)
    resp = _get_table().query(
        KeyConditionExpression=Key("pk").eq(_pk(device_id))
        & Key("sk").between(f"DAY#{_date_key(start)}", f"DAY#{_date_key(today)}")
    )
    by_date = {item["sk"].removeprefix("DAY#"): item for item in resp.get("Items", [])}
    out = []
    for i in range(n):
        key = _date_key(start + timedelta(days=i))
        item = by_date.get(key, {})
        out.append({
            "date": key,
            "lessons": int(item.get("lessons", 0)),
            "checkins": int(item.get("checkins", 0)),
            "xp": int(item.get("xp", 0)),
        })
    return out


def get_month_summary(device_id: str) -> dict[str, int]:
    today = date.today()
    prefix = f"DAY#{today.year:04d}-{today.month:02d}"
    resp = _get_table().query(
        KeyConditionExpression=Key("pk").eq(_pk(device_id)) & Key("sk").begins_with(prefix)
    )
    lessons = checkins = xp = 0
    for item in resp.get("Items", []):
        lessons += int(item.get("lessons", 0))
        checkins += int(item.get("checkins", 0))
        xp += int(item.get("xp", 0))
    return {"lessons": lessons, "checkins": checkins, "xp": xp}