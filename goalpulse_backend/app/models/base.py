"""Shared base models for GoalPulse domain entities."""

from datetime import datetime

from pydantic import BaseModel


class TimestampModel(BaseModel):
    """Mixin‑style base that adds created / updated audit timestamps."""

    created_at: datetime | None = None
    updated_at: datetime | None = None
