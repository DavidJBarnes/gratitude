from datetime import date, timedelta
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Gratitude


async def calculate_streaks(db: AsyncSession, user_id, client_today: Optional[date] = None) -> dict:
    result = await db.execute(
        select(Gratitude.entry_date)
        .where(Gratitude.user_id == user_id)
        .order_by(Gratitude.entry_date.desc())
    )
    dates = sorted({row[0] for row in result.fetchall()})

    if not dates:
        return {"current_streak": 0, "longest_streak": 0, "total_entries": 0, "streak_label": "Start your journey!"}

    total_entries = len(dates)

    # Calculate all streaks
    streaks = []
    current = 1
    for i in range(1, len(dates)):
        if dates[i] - dates[i - 1] == timedelta(days=1):
            current += 1
        else:
            streaks.append(current)
            current = 1
    streaks.append(current)

    longest_streak = max(streaks)

    # Use client-supplied date so the streak reflects the user's local calendar,
    # not the server's timezone.  Fall back to server date only when absent.
    today = client_today or date.today()
    current_streak = 0
    # Start from today or the most recent entry date, whichever is later,
    # so entries posted slightly ahead of the server clock are not skipped.
    check = max(today, dates[-1])
    date_set = set(dates)

    while check in date_set:
        current_streak += 1
        check -= timedelta(days=1)

    # If no entry today, check if yesterday is there (streak not broken yet today)
    if current_streak == 0 and (today - timedelta(days=1)) in date_set:
        check = today - timedelta(days=1)
        while check in date_set:
            current_streak += 1
            check -= timedelta(days=1)

    return {
        "current_streak": current_streak,
        "longest_streak": longest_streak,
        "total_entries": total_entries,
        "streak_label": _streak_label(current_streak),
    }


def _streak_label(days: int) -> str:
    if days == 0:
        return "Start your journey!"
    if days == 1:
        return "1 day - Great start!"
    if days < 7:
        return f"{days} days - Building momentum!"
    if days == 7:
        return "1 week - On a roll!"
    if days < 14:
        return f"{days} days - Unstoppable!"
    if days < 30:
        return f"{days} days - Gratitude warrior!"
    if days < 60:
        return f"{days} days - One month strong!"
    if days < 90:
        return f"{days} days - Gratitude master!"
    if days < 180:
        return f"{days} days - Legendary!"
    if days < 365:
        return f"{days} days - Transcendent!"
    return f"{days} days - Gratitude immortal!"
