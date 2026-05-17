"""AI-powered endpoints (Gemini integration)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Path, status

from app.middleware.auth_middleware import get_current_user, require_manager
from app.services.ai_service import (
    suggest_goals,
    generate_quarterly_summary_text,
    predict_goal_risks,
    recommend_kpi,
)
from app.services.firebase_service import db

router = APIRouter(prefix="/v1/ai", tags=["ai"])

GOALS_COL = "goals"
CHECKINS_COL = "checkins"
USERS_COL = "users"


# ── POST /ai/suggest-goals ────────────────────────────────────────────────────

@router.post("/suggest-goals")
async def suggest_goals_endpoint(
    body: dict = Body(...),
    user: dict = Depends(get_current_user),
):
    """Return 3 AI-generated SMART goal suggestions for a thrust area."""
    role = body.get("role", user.get("role", "Employee"))
    department = body.get("department", "")
    thrust_area = body.get("thrust_area", "General")
    existing = body.get("existing_goal_titles", [])

    result = await suggest_goals(
        role=role,
        department=department,
        thrust_area=thrust_area,
        existing_goal_titles=existing,
    )
    return result


# ── POST /ai/risk-prediction ──────────────────────────────────────────────────

@router.post("/risk-prediction")
async def risk_prediction_endpoint(
    body: dict = Body(...),
    user: dict = Depends(require_manager),
):
    """Predict at-risk goals for a given goal sheet."""
    goal_id: str = body.get("goal_id", "")
    quarter: str = body.get("quarter", "Q1")

    if not goal_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="goal_id is required.",
        )

    goal_doc = db.collection(GOALS_COL).document(goal_id).get()
    if not goal_doc.exists:
        raise HTTPException(status_code=404, detail="Goal sheet not found.")

    goal = goal_doc.to_dict()

    # Fetch the check-in for the earliest quarter to compute trajectory.
    checkins = list(
        db.collection(CHECKINS_COL)
        .where("goal_id", "==", goal_id)
        .where("quarter", "==", "Q1")
        .limit(1)
        .get()
    )
    checkin_actuals: dict[str, float] = {}
    if checkins:
        for actual in checkins[0].to_dict().get("actuals", []):
            checkin_actuals[actual["goal_item_id"]] = float(
                actual.get("progress_score", 0)
            )

    goals_with_actuals = []
    for item in goal.get("goals", []):
        item_id = item.get("goal_item_id", "")
        goals_with_actuals.append(
            {
                "goal_item_id": item_id,
                "title": item.get("title", ""),
                "uom_type": item.get("uom_type", ""),
                "target": item.get("target"),
                "q1_score": checkin_actuals.get(item_id, 0),
            }
        )

    return await predict_goal_risks(goals_with_actuals, quarter)


# ── POST /ai/kpi-recommendations ──────────────────────────────────────────────

@router.post("/kpi-recommendations")
async def kpi_recommendations_endpoint(
    body: dict = Body(...),
    user: dict = Depends(get_current_user),
):
    """Recommend UoM type and target for a goal title + thrust area."""
    thrust_area = body.get("thrust_area", "")
    goal_title = body.get("goal_title", "")
    role = body.get("role", user.get("role", "Employee"))

    if not goal_title or not thrust_area:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="thrust_area and goal_title are required.",
        )

    return await recommend_kpi(
        thrust_area=thrust_area,
        goal_title=goal_title,
        role=role,
    )


# ── POST /checkins/{checkin_id}/ai-summary ───────────────────────────────────

@router.post("/checkins/{checkin_id}/ai-summary")
async def generate_ai_summary(
    checkin_id: str = Path(...),
    user: dict = Depends(get_current_user),
):
    """Generate and persist an AI summary for a check-in."""
    checkin_doc = db.collection(CHECKINS_COL).document(checkin_id).get()
    if not checkin_doc.exists:
        raise HTTPException(status_code=404, detail="Check-in not found.")

    checkin = checkin_doc.to_dict()

    # Verify ownership or manager access.
    if checkin.get("employee_id") != user["uid"] and user.get("role") not in (
        "manager",
        "admin",
    ):
        raise HTTPException(status_code=403, detail="Access denied.")

    # Fetch goal sheet for context.
    goal_doc = db.collection(GOALS_COL).document(checkin["goal_id"]).get()
    goal_data = goal_doc.to_dict() if goal_doc.exists else {}

    # Fetch user profile for name.
    user_doc = db.collection(USERS_COL).document(checkin["employee_id"]).get()
    user_data = user_doc.to_dict() if user_doc.exists else {}
    employee_name = user_data.get("display_name") or user_data.get("email", "Employee")
    role = user_data.get("role", "Employee")

    # Build goals_with_actuals list.
    goal_items = {
        g["goal_item_id"]: g for g in goal_data.get("goals", [])
    }
    goals_with_actuals = []
    for actual in checkin.get("actuals", []):
        item = goal_items.get(actual.get("goal_item_id", ""), {})
        goals_with_actuals.append(
            {
                "title": item.get("title", actual.get("goal_item_id", "")),
                "target": item.get("target"),
                "actual": actual.get("actual"),
                "progress_score": float(actual.get("progress_score", 0)),
            }
        )

    manager_comment = checkin.get("manager_comment")
    quarter = checkin.get("quarter", "Q1")

    summary = await generate_quarterly_summary_text(
        employee_name=employee_name,
        role=role,
        quarter=quarter,
        goals_with_actuals=goals_with_actuals,
        manager_comment=manager_comment,
    )

    # Persist to Firestore.
    db.collection(CHECKINS_COL).document(checkin_id).update(
        {"ai_summary": summary, "ai_summary_generated_at": datetime.now(timezone.utc)}
    )

    return {"summary": summary}
