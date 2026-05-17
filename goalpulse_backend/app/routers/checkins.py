"""Quarterly check-in endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.middleware.auth_middleware import get_current_user, require_employee, require_manager
from app.models.checkin import CheckinCreate
from app.services.checkin_service import checkin_service

router = APIRouter(prefix="/v1/checkins", tags=["checkins"])


class ManagerReviewRequest(BaseModel):
    comment: str


# ── POST /checkins ────────────────────────────────────────────────────────


@router.post("/", status_code=status.HTTP_201_CREATED)
async def submit_checkin(
    body: CheckinCreate,
    user: dict = Depends(require_employee),
):
    """Submit quarterly actuals for a goal sheet."""
    try:
        checkin = checkin_service.submit_checkin(user["uid"], body)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )
    return _format_checkin(checkin)


# ── GET /checkins/{goal_id} ──────────────────────────────────────────────


@router.get("/{goal_id}")
async def get_checkins(
    goal_id: str,
    user: dict = Depends(get_current_user),
):
    """Get all check-ins for a goal sheet."""
    checkins = checkin_service.get_checkins(
        goal_id, user["uid"], user["role"]
    )
    return [_format_checkin(c) for c in checkins]


# ── PUT /checkins/{checkin_id}/manager-review ────────────────────────────


@router.put("/{checkin_id}/manager-review")
async def manager_review(
    checkin_id: str,
    body: ManagerReviewRequest,
    user: dict = Depends(require_manager),
):
    """Manager reviews a check-in with a comment."""
    checkin = checkin_service.manager_review(
        checkin_id, user["uid"], body.comment
    )
    return _format_checkin(checkin)


# ── Helpers ───────────────────────────────────────────────────────────────


def _format_checkin(checkin: dict) -> dict:
    """Normalise Firestore document to camelCase API response."""
    return {
        "id": checkin.get("id", ""),
        "goalId": checkin.get("goal_id", ""),
        "employeeId": checkin.get("employee_id", ""),
        "quarter": checkin.get("quarter", ""),
        "status": checkin.get("status", ""),
        "managerComment": checkin.get("manager_comment"),
        "aiSummary": checkin.get("ai_summary"),
        "actuals": [
            {
                "goalItemId": a.get("goal_item_id", ""),
                "goalTitle": a.get("goal_title", ""),
                "uomType": a.get("uom_type", ""),
                "target": a.get("target"),
                "actualAchievement": a.get("actual_achievement"),
                "status": a.get("status", ""),
                "progressScore": a.get("progress_score", 0),
                "weightage": a.get("weightage", 0),
            }
            for a in checkin.get("actuals", [])
        ],
        "overallScore": checkin.get("overall_score", 0),
        "employeeSubmittedAt": _iso(checkin.get("employee_submitted_at")),
        "managerReviewedAt": _iso(checkin.get("manager_reviewed_at")),
    }


def _iso(val) -> str | None:
    if val is None:
        return None
    if hasattr(val, "isoformat"):
        return val.isoformat()
    return str(val)
