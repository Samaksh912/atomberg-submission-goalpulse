"""Admin panel endpoints — user management, cycles, audit logs, goal unlock."""

from __future__ import annotations

from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel

from app.middleware.auth_middleware import (
    get_current_user,
    require_admin,
)
from app.models.cycle import CycleCreate, CycleUpdate
from app.services.admin_service import admin_service
from app.services.goal_service import goal_service

router = APIRouter(prefix="/v1/admin", tags=["admin"])
goals_router = APIRouter(prefix="/v1/goals", tags=["admin_goal_unlock"])


# ─────────────────────────────────────────────────────────────────────────────
#  User Management
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/users")
async def get_users(
    search: str = Query(""),
    role: str = Query(""),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    _user: dict = Depends(require_admin),
):
    """Paginated list of all users with optional search and role filter."""
    return admin_service.get_users(
        search=search, role_filter=role, page=page, page_size=page_size
    )


class CreateUserRequest(BaseModel):
    email: str
    password: str
    display_name: str = ""
    role: str = "employee"
    manager_id: Optional[str] = None
    department: str = ""
    designation: str = ""


@router.post("/users", status_code=status.HTTP_201_CREATED)
async def create_user(
    body: CreateUserRequest,
    _user: dict = Depends(require_admin),
):
    """Create a Firebase Auth user and Firestore profile."""
    return admin_service.create_user(body.model_dump())


class UpdateUserRequest(BaseModel):
    display_name: Optional[str] = None
    role: Optional[str] = None
    manager_id: Optional[str] = None
    department: Optional[str] = None
    designation: Optional[str] = None
    is_active: Optional[bool] = None


@router.put("/users/{user_id}")
async def update_user(
    user_id: str,
    body: UpdateUserRequest,
    _user: dict = Depends(require_admin),
):
    """Update a user's Firestore profile."""
    return admin_service.update_user(
        user_id, body.model_dump(exclude_none=True)
    )


# ─────────────────────────────────────────────────────────────────────────────
#  Audit Logs
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/audit-logs")
async def get_audit_logs(
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    actor_id: Optional[str] = Query(None),
    action: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    _user: dict = Depends(require_admin),
):
    """Paginated audit log with optional filters."""
    result = admin_service.get_audit_logs(
        start_date=start_date,
        end_date=end_date,
        actor_id=actor_id,
        action_filter=action,
        page=page,
        page_size=page_size,
    )
    return {
        **result,
        "logs": [_format_log(l) for l in result["logs"]],
    }


# ─────────────────────────────────────────────────────────────────────────────
#  Cycles
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/cycles/active")
async def get_active_cycle(
    _user: dict = Depends(get_current_user),
):
    """Return the currently active cycle (accessible to all roles)."""
    cycle = admin_service.get_active_cycle()
    if cycle is None:
        return None
    return _format_cycle(cycle)


@router.get("/cycles")
async def list_cycles(
    _user: dict = Depends(require_admin),
):
    """Return all cycles ordered by year descending."""
    return [_format_cycle(c) for c in admin_service.list_cycles()]


@router.post("/cycles", status_code=status.HTTP_201_CREATED)
async def create_cycle(
    body: CycleCreate,
    user: dict = Depends(require_admin),
):
    """Create a new performance cycle."""
    return _format_cycle(admin_service.create_cycle(user["uid"], body))


@router.put("/cycles/{cycle_id}")
async def update_cycle(
    cycle_id: str,
    body: CycleUpdate,
    user: dict = Depends(require_admin),
):
    """Partially update a cycle's phase windows."""
    return _format_cycle(admin_service.update_cycle(cycle_id, user["uid"], body))


@router.post("/cycles/{cycle_id}/activate")
async def activate_cycle(
    cycle_id: str,
    user: dict = Depends(require_admin),
):
    """Activate a cycle, deactivating all others."""
    return _format_cycle(admin_service.activate_cycle(cycle_id, user["uid"]))


# ─────────────────────────────────────────────────────────────────────────────
#  Org Stats (for admin dashboard)
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/stats")
async def get_stats(
    _user: dict = Depends(require_admin),
):
    """Org-wide KPI counts for the admin dashboard."""
    return admin_service.get_org_stats()


# ─────────────────────────────────────────────────────────────────────────────
#  Goal Unlock (mounted on /v1/goals)
# ─────────────────────────────────────────────────────────────────────────────


class UnlockGoalItemRequest(BaseModel):
    goal_item_id: str
    reason: str


@goals_router.post("/{goal_id}/unlock-item")
async def unlock_goal_item(
    goal_id: str,
    body: UnlockGoalItemRequest,
    user: dict = Depends(require_admin),
):
    """Admin unlocks a single goal item. Creates a mandatory audit log."""
    return goal_service.unlock_goal_item(
        goal_id=goal_id,
        goal_item_id=body.goal_item_id,
        admin_id=user["uid"],
        reason=body.reason,
    )


# ─────────────────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────────────────


def _iso(val) -> Optional[str]:
    if val is None:
        return None
    if hasattr(val, "isoformat"):
        return val.isoformat()
    return str(val)


def _format_log(d: dict) -> dict:
    details = d.get("details") or {}
    return {
        "id": d.get("id", ""),
        "timestamp": _iso(d.get("timestamp")),
        "actorId": d.get("actor_id", ""),
        "actorRole": details.get("actor_role", ""),
        "employeeId": details.get("employee_id", ""),
        "action": d.get("action", ""),
        "targetType": details.get("target_type", ""),
        "targetId": details.get("target_id", ""),
        "fieldChanged": details.get("field_changed", ""),
        "oldValue": details.get("old_value"),
        "newValue": details.get("new_value"),
        "reason": details.get("reason", ""),
        "goalTitle": details.get("goal_title", ""),
        "entityId": d.get("entity_id", ""),
    }


def _format_phase(p: dict) -> dict:
    return {
        "openDate": _iso(p.get("open_date")),
        "closeDate": _iso(p.get("close_date")),
    }


def _format_cycle(c: dict) -> dict:
    return {
        "id": c.get("id", ""),
        "year": c.get("year"),
        "label": c.get("label", ""),
        "isActive": c.get("is_active", False),
        "goalSetting": _format_phase(c.get("goal_setting") or {}),
        "q1": _format_phase(c.get("q1") or {}),
        "q2": _format_phase(c.get("q2") or {}),
        "q3": _format_phase(c.get("q3") or {}),
        "q4": _format_phase(c.get("q4") or {}),
        "createdAt": _iso(c.get("created_at")),
        "activatedAt": _iso(c.get("activated_at")),
    }
