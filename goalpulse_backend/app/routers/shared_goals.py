"""Shared / cascaded goal endpoints."""

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel

from app.middleware.auth_middleware import get_current_user, require_employee, require_manager
from app.models.shared_goal import SharedGoalCreate, UpdateWeightageRequest
from app.services.shared_goal_service import shared_goal_service

router = APIRouter(prefix="/v1/shared-goals", tags=["shared_goals"])


# ── POST /shared-goals ────────────────────────────────────────────────────


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_shared_goal(
    body: SharedGoalCreate,
    user: dict = Depends(require_manager),
):
    """Push a shared KPI to multiple team member goal sheets."""
    result = shared_goal_service.create_shared_goal(user["uid"], body)
    return {
        "id": result["id"],
        "updatedCount": result.get("updated_count", 0),
        "message": f"Shared goal pushed to {result.get('updated_count', 0)} employees.",
    }


# ── GET /shared-goals ─────────────────────────────────────────────────────


@router.get("/")
async def list_shared_goals(
    user: dict = Depends(require_manager),
):
    """List shared goals created by this manager/admin."""
    docs = shared_goal_service.list_shared_goals(user["uid"])
    return [_format_shared_goal(d) for d in docs]


# ── PUT /shared-goals/{id}/weightage ─────────────────────────────────────


@router.put("/{shared_goal_id}/weightage")
async def update_weightage(
    shared_goal_id: str,
    body: UpdateWeightageRequest,
    user: dict = Depends(require_employee),
):
    """Recipient updates their local weightage for a shared goal."""
    shared_goal_service.update_weightage(
        shared_goal_id, user["uid"], body.weightage
    )
    return {"message": "Weightage updated."}


# ── Helpers ───────────────────────────────────────────────────────────────


def _format_shared_goal(d: dict) -> dict:
    return {
        "id": d.get("id", ""),
        "createdBy": d.get("created_by", ""),
        "cycleId": d.get("cycle_id", ""),
        "thrustArea": d.get("thrust_area", ""),
        "title": d.get("title", ""),
        "description": d.get("description", ""),
        "uomType": d.get("uom_type", ""),
        "target": d.get("target"),
        "suggestedWeightage": d.get("suggested_weightage", 20),
        "recipientIds": d.get("recipient_ids", []),
        "ownerEmployeeId": d.get("owner_employee_id", ""),
        "linkedGoalItemIds": d.get("linked_goal_item_ids", {}),
        "createdAt": _iso(d.get("created_at")),
    }


def _iso(val) -> str | None:
    if val is None:
        return None
    if hasattr(val, "isoformat"):
        return val.isoformat()
    return str(val)
