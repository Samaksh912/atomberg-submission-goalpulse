"""Pydantic models for quarterly check-in operations."""

from __future__ import annotations

from typing import Optional
from pydantic import BaseModel, Field


class ActualEntry(BaseModel):
    """A single goal-item's actual achievement for a quarter."""

    goal_item_id: str
    actual_achievement: float | str
    status: str = Field(
        ...,
        pattern=r"^(not_started|on_track|completed)$",
        description="Goal-item status for the quarter.",
    )


class CheckinCreate(BaseModel):
    """Request body for submitting a quarterly check-in."""

    goal_id: str = Field(..., description="Goal-sheet document ID.")
    quarter: str = Field(
        ...,
        pattern=r"^Q[1-4]$",
        description="Quarter identifier: Q1, Q2, Q3 or Q4.",
    )
    actuals: list[ActualEntry] = Field(
        ..., min_length=1, description="Actual achievement for each goal item."
    )


class CheckinActualResponse(BaseModel):
    """Single goal-item actual with computed progress score."""

    goal_item_id: str
    goal_title: str = ""
    uom_type: str = ""
    target: float | str | None = None
    actual_achievement: float | str
    status: str
    progress_score: float = 0.0
    weightage: float = 0.0


class CheckinResponse(BaseModel):
    """API response for a check-in record."""

    id: str
    goal_id: str
    employee_id: str
    quarter: str
    status: str
    manager_comment: Optional[str] = None
    ai_summary: Optional[str] = None
    actuals: list[CheckinActualResponse]
    overall_score: float = 0.0
    employee_submitted_at: Optional[str] = None
    manager_reviewed_at: Optional[str] = None
