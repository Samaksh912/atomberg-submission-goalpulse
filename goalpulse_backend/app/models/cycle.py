"""Pydantic models for goal-setting cycle management."""

from __future__ import annotations

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class PhaseWindow(BaseModel):
    """Date window for a single phase (goal-setting or quarterly check-in)."""
    open_date: datetime
    close_date: datetime


class CycleCreate(BaseModel):
    """Request body to create a new performance cycle."""
    year: int = Field(..., ge=2020, le=2100)
    label: str = ""           # e.g. "FY 2025–26"
    goal_setting: PhaseWindow
    q1: PhaseWindow
    q2: PhaseWindow
    q3: PhaseWindow
    q4: PhaseWindow


class CycleUpdate(BaseModel):
    """Partial update for a cycle (all fields optional)."""
    year: Optional[int] = None
    label: Optional[str] = None
    goal_setting: Optional[PhaseWindow] = None
    q1: Optional[PhaseWindow] = None
    q2: Optional[PhaseWindow] = None
    q3: Optional[PhaseWindow] = None
    q4: Optional[PhaseWindow] = None
