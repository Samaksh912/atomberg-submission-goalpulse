"""Pydantic models for shared / cascaded goal operations."""

from __future__ import annotations

from typing import Optional
from pydantic import BaseModel, Field


class SharedGoalCreate(BaseModel):
    """Request body to push a shared KPI to team members."""

    cycle_id: str
    thrust_area: str
    title: str
    description: str = ""
    uom_type: str
    target: float | str
    suggested_weightage: float = Field(20.0, ge=10.0, le=100.0)
    recipient_ids: list[str] = Field(..., min_length=1)
    owner_employee_id: str  # must be one of recipient_ids


class UpdateWeightageRequest(BaseModel):
    """Employee adjusts their local weightage for a shared goal."""

    weightage: float = Field(..., ge=10.0, le=100.0)


class SharedGoalResponse(BaseModel):
    """API response for a shared goal document."""

    id: str
    created_by: str
    cycle_id: str
    thrust_area: str
    title: str
    description: str
    uom_type: str
    target: float | str
    suggested_weightage: float
    recipient_ids: list[str]
    owner_employee_id: str
    linked_goal_item_ids: dict  # {employeeId: goalItemId}
    created_at: Optional[str] = None
