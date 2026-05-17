"""Pydantic models for Goal Sheet CRUD."""

from __future__ import annotations

from datetime import datetime
from typing import Optional, Union

from pydantic import BaseModel, Field, field_validator


# ── Request models ────────────────────────────────────────────────────────


class GoalItemCreate(BaseModel):
    """A single goal inside a goal sheet (create / update payload)."""

    thrust_area: str
    title: str = Field(..., max_length=100)
    description: str = Field("", max_length=500)
    uom_type: str  # numeric_min | numeric_max | percent_min | percent_max | timeline | zero
    target: Union[float, str]  # float for numeric/%, string date for timeline
    weightage: float = Field(..., ge=10, le=100)


class GoalSheetCreate(BaseModel):
    """Payload for creating or updating a full goal sheet."""

    cycle_id: str
    goals: list[GoalItemCreate] = Field(..., min_length=1, max_length=8)

    @field_validator("goals")
    @classmethod
    def validate_weightage(cls, goals: list[GoalItemCreate]) -> list[GoalItemCreate]:
        total = sum(g.weightage for g in goals)
        if abs(total - 100.0) > 0.01:
            raise ValueError(
                f"Total weightage must equal 100%. Current: {total}%"
            )
        return goals


# ── Response models ───────────────────────────────────────────────────────


class GoalItemResponse(BaseModel):
    """A single goal as returned to clients."""

    goal_item_id: str
    thrust_area: str
    title: str
    description: str
    uom_type: str
    target: Union[float, str]
    weightage: float
    is_shared: bool
    shared_goal_id: Optional[str] = None
    is_locked: bool
    quarterly_data: dict  # {Q1: {...}, Q2: {...}, Q3: {...}, Q4: {...}}
    ai_suggested: bool


class GoalSheetResponse(BaseModel):
    """Full goal sheet as returned to clients."""

    id: str
    employee_id: str
    manager_id: Optional[str] = None
    cycle_id: str
    sheet_status: str
    goals: list[GoalItemResponse]
    total_weightage: float
    submitted_at: Optional[datetime] = None
    approved_at: Optional[datetime] = None
    manager_comment: Optional[str] = None
    created_at: datetime
