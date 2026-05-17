"""Goal CRUD & lifecycle endpoints."""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

from app.middleware.auth_middleware import get_current_user, require_employee, require_manager
from app.models.goal import GoalSheetCreate, GoalSheetResponse, GoalItemResponse
from app.services.goal_service import goal_service

router = APIRouter(prefix="/v1/goals", tags=["goals"])


# ── Request models for manager actions ────────────────────────────────────


class GoalEditItem(BaseModel):
    goalItemId: str
    target: Optional[float | str] = None
    weightage: Optional[float] = None


class ApproveRequest(BaseModel):
    comment: Optional[str] = None
    edited_goals: Optional[list[GoalEditItem]] = None


class ReturnRequest(BaseModel):
    comment: str


# ── GET /goals/my ─────────────────────────────────────────────────────────


@router.get("/my")
async def get_my_goals(
    cycle_id: str = Query(..., description="Active cycle ID"),
    user: dict = Depends(require_employee),
):
    """Return the employee's goal sheet for the given cycle."""
    sheet = goal_service.get_my_goals(user["uid"], cycle_id)
    if not sheet:
        return None
    return _format_sheet(sheet)


# ── GET /goals/team ───────────────────────────────────────────────────────


@router.get("/team")
async def get_team_goals(
    cycle_id: str = Query("cycle_2025", description="Active cycle ID"),
    status_filter: Optional[str] = Query(None, alias="status"),
    user: dict = Depends(require_manager),
):
    """Return all goal sheets for the manager's direct reports."""
    sheets = goal_service.get_team_goals(user["uid"], cycle_id, status_filter)
    return [_format_sheet_with_employee(s) for s in sheets]


# ── POST /goals ───────────────────────────────────────────────────────────


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_goal_sheet(
    body: GoalSheetCreate,
    user: dict = Depends(require_employee),
):
    """Create a new goal sheet for the employee."""
    try:
        doc_id = goal_service.create_goal_sheet(
            employee_id=user["uid"],
            manager_id=user.get("manager_id"),
            data=body,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )
    return {"id": doc_id, "message": "Goal sheet created."}


# ── PUT /goals/{goal_id} ─────────────────────────────────────────────────


@router.put("/{goal_id}")
async def update_goal_sheet(
    goal_id: str,
    body: GoalSheetCreate,
    user: dict = Depends(require_employee),
):
    """Update a draft / returned goal sheet."""
    try:
        goal_service.update_goal_sheet(goal_id, user["uid"], body)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )
    return {"message": "Goal sheet updated."}


# ── POST /goals/{goal_id}/submit ─────────────────────────────────────────


@router.post("/{goal_id}/submit")
async def submit_goal_sheet(
    goal_id: str,
    user: dict = Depends(require_employee),
):
    """Submit a goal sheet for manager approval."""
    goal_service.submit_goal_sheet(goal_id, user["uid"])
    return {"message": "Goal sheet submitted for approval."}


# ── PUT /goals/{goal_id}/approve ─────────────────────────────────────────


@router.put("/{goal_id}/approve")
async def approve_goal_sheet(
    goal_id: str,
    body: ApproveRequest,
    user: dict = Depends(require_manager),
):
    """Approve a submitted goal sheet (manager only)."""
    try:
        edited = (
            [eg.model_dump() for eg in body.edited_goals]
            if body.edited_goals
            else None
        )
        goal_service.approve_goal_sheet(
            goal_id, user["uid"], body.comment, edited
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )
    return {"message": "Goal sheet approved and locked."}


# ── PUT /goals/{goal_id}/return ──────────────────────────────────────────


@router.put("/{goal_id}/return")
async def return_goal_sheet(
    goal_id: str,
    body: ReturnRequest,
    user: dict = Depends(require_manager),
):
    """Return a submitted goal sheet for rework (manager only)."""
    goal_service.return_goal_sheet(goal_id, user["uid"], body.comment)
    return {"message": "Goal sheet returned with feedback."}


# ── GET /goals/{goal_id} ─────────────────────────────────────────────────


@router.get("/{goal_id}")
async def get_goal_by_id(
    goal_id: str,
    user: dict = Depends(get_current_user),
):
    """Get a specific goal sheet by ID.

    - employee: own goals only
    - manager: own team
    - admin: any
    """
    sheet = goal_service.get_goal_by_id(goal_id)
    if not sheet:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Goal sheet not found.",
        )

    role = user["role"]
    if role == "employee" and sheet["employee_id"] != user["uid"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only view your own goals.",
        )
    if role == "manager":
        if (
            sheet["employee_id"] != user["uid"]
            and sheet.get("manager_id") != user["uid"]
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only view your team's goals.",
            )

    return _format_sheet(sheet)


# ── Helpers ───────────────────────────────────────────────────────────────


def _format_sheet(sheet: dict) -> dict:
    """Normalise Firestore document to camelCase API response."""
    goals = sheet.get("goals", [])
    return {
        "id": sheet["id"],
        "employeeId": sheet.get("employee_id", ""),
        "managerId": sheet.get("manager_id"),
        "cycleId": sheet.get("cycle_id", ""),
        "sheetStatus": sheet.get("sheet_status", "draft"),
        "goals": [_format_goal(g) for g in goals],
        "totalWeightage": sheet.get("total_weightage", 0),
        "submittedAt": _iso(sheet.get("submitted_at")),
        "approvedAt": _iso(sheet.get("approved_at")),
        "managerComment": sheet.get("manager_comment"),
        "createdAt": _iso(sheet.get("created_at")),
    }


def _format_sheet_with_employee(sheet: dict) -> dict:
    """Like _format_sheet but includes joined employee profile."""
    base = _format_sheet(sheet)
    base["employeeName"] = sheet.get("employee_name", "")
    base["employeeEmail"] = sheet.get("employee_email", "")
    base["employeeDepartment"] = sheet.get("employee_department", "")
    return base


def _format_goal(g: dict) -> dict:
    return {
        "goalItemId": g.get("goal_item_id", ""),
        "thrustArea": g.get("thrust_area", ""),
        "title": g.get("title", ""),
        "description": g.get("description", ""),
        "uomType": g.get("uom_type", ""),
        "target": g.get("target", 0),
        "weightage": g.get("weightage", 0),
        "isShared": g.get("is_shared", False),
        "sharedGoalId": g.get("shared_goal_id"),
        "isLocked": g.get("is_locked", False),
        "quarterlyData": g.get(
            "quarterly_data",
            {"Q1": None, "Q2": None, "Q3": None, "Q4": None},
        ),
        "aiSuggested": g.get("ai_suggested", False),
    }


def _iso(val) -> str | None:
    """Convert datetime or Firestore Timestamp to ISO string."""
    if val is None:
        return None
    if hasattr(val, "isoformat"):
        return val.isoformat()
    return str(val)
