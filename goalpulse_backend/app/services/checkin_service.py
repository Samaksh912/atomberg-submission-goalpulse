"""Business logic for quarterly check-in operations."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import HTTPException, status

from app.models.checkin import ActualEntry, CheckinCreate
from app.services.firebase_service import db
from app.services.notification_service import create_notification, create_audit_log
from app.utils.progress_calculator import calculate_progress_score


COLLECTION = "checkins"
GOALS_COLLECTION = "goals"


class CheckinService:
    """Encapsulates all check-in operations against Firestore."""

    # ── Submit ────────────────────────────────────────────────────────────

    @staticmethod
    def submit_checkin(employee_id: str, data: CheckinCreate) -> dict[str, Any]:
        """Submit quarterly actuals for a goal sheet.

        1. Verify goal ownership and status
        2. Compute progress scores
        3. Create check-in document
        4. Update goal document's quarterlyData
        5. Notify manager
        """
        # Fetch goal sheet.
        goal_doc = db.collection(GOALS_COLLECTION).document(data.goal_id).get()
        if not goal_doc.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Goal sheet not found.",
            )
        goal = goal_doc.to_dict()
        goal["id"] = goal_doc.id

        if goal["employee_id"] != employee_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only submit check-ins for your own goals.",
            )
        if goal.get("sheet_status") not in ("approved", "locked"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Goal sheet must be approved before submitting check-ins.",
            )

        # Check for duplicate submission.
        existing = list(
            db.collection(COLLECTION)
            .where("goal_id", "==", data.goal_id)
            .where("quarter", "==", data.quarter)
            .where("employee_id", "==", employee_id)
            .limit(1)
            .get()
        )
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Check-in for {data.quarter} already submitted. Use the update flow.",
            )

        # Build goal item lookup.
        goal_items = {g["goal_item_id"]: g for g in goal.get("goals", [])}

        now = datetime.now(timezone.utc)
        actuals_list = []

        for entry in data.actuals:
            gi = goal_items.get(entry.goal_item_id)
            if not gi:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Goal item {entry.goal_item_id} not found in goal sheet.",
                )

            score = calculate_progress_score(
                gi["uom_type"], gi["target"], entry.actual_achievement
            )

            actuals_list.append({
                "goal_item_id": entry.goal_item_id,
                "goal_title": gi.get("title", ""),
                "uom_type": gi.get("uom_type", ""),
                "target": gi.get("target"),
                "actual_achievement": entry.actual_achievement,
                "status": entry.status,
                "progress_score": round(score, 2),
                "weightage": gi.get("weightage", 0),
            })

            # Sync actuals to linked recipients if this is a shared goal and
            # the submitting employee is the designated owner.
            if gi.get("is_shared") and gi.get("shared_goal_id"):
                shared_goal_id = gi["shared_goal_id"]
                # Lazy-import to avoid circular dependency.
                from app.services.shared_goal_service import shared_goal_service as _sgs
                try:
                    _sgs.sync_actuals(
                        shared_goal_id=shared_goal_id,
                        owner_id=employee_id,
                        quarter=data.quarter,
                        actual=entry.actual_achievement,
                        progress_score=round(score, 2),
                    )
                except Exception as sync_err:
                    # Non-fatal — log and continue.
                    print(f"[checkin] sync_actuals failed for {shared_goal_id}: {sync_err}")

        # Compute weighted overall score.
        total_weight = sum(a["weightage"] for a in actuals_list)
        overall_score = 0.0
        if total_weight > 0:
            overall_score = sum(
                a["progress_score"] * a["weightage"] for a in actuals_list
            ) / total_weight

        # Create check-in document.
        checkin_data = {
            "goal_id": data.goal_id,
            "employee_id": employee_id,
            "quarter": data.quarter,
            "status": "actuals_submitted",
            "manager_comment": None,
            "ai_summary": None,
            "actuals": actuals_list,
            "overall_score": round(overall_score, 2),
            "employee_submitted_at": now,
            "manager_reviewed_at": None,
            "created_at": now,
        }
        _, ref = db.collection(COLLECTION).add(checkin_data)
        checkin_data["id"] = ref.id

        # Update goal document's quarterlyData.
        goals_updated = goal.get("goals", [])
        for a in actuals_list:
            for g in goals_updated:
                if g["goal_item_id"] == a["goal_item_id"]:
                    qd = g.get("quarterly_data", {})
                    qd[data.quarter] = {
                        "actual": a["actual_achievement"],
                        "status": a["status"],
                        "progress_score": a["progress_score"],
                    }
                    g["quarterly_data"] = qd

        db.collection(GOALS_COLLECTION).document(data.goal_id).update({
            "goals": goals_updated,
            "updated_at": now,
        })

        # Notify manager.
        manager_id = goal.get("manager_id")
        if manager_id:
            create_notification(
                recipient_id=manager_id,
                notification_type="checkin_submitted",
                title=f"{data.quarter} Check-In Submitted",
                body=f"An employee has submitted {data.quarter} actuals.",
                related_entity_type="checkin",
                related_entity_id=ref.id,
            )

        # Audit log.
        create_audit_log(
            action="checkin_submitted",
            actor_id=employee_id,
            entity_id=ref.id,
            details={"quarter": data.quarter, "overall_score": overall_score},
        )

        return checkin_data

    # ── Get check-ins ─────────────────────────────────────────────────────

    @staticmethod
    def get_checkins(
        goal_id: str,
        requester_id: str,
        requester_role: str,
    ) -> list[dict[str, Any]]:
        """Return all check-ins for a goal sheet, verifying access."""
        # Verify access.
        goal_doc = db.collection(GOALS_COLLECTION).document(goal_id).get()
        if not goal_doc.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Goal sheet not found.",
            )
        goal = goal_doc.to_dict()

        if requester_role == "employee" and goal["employee_id"] != requester_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only view your own check-ins.",
            )
        if requester_role == "manager":
            if (
                goal["employee_id"] != requester_id
                and goal.get("manager_id") != requester_id
            ):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="You can only view your team's check-ins.",
                )

        docs = list(
            db.collection(COLLECTION)
            .where("goal_id", "==", goal_id)
            .order_by("created_at")
            .get()
        )
        results = []
        for doc in docs:
            d = doc.to_dict()
            d["id"] = doc.id
            results.append(d)
        return results

    # ── Manager review ────────────────────────────────────────────────────

    @staticmethod
    def manager_review(
        checkin_id: str,
        manager_id: str,
        comment: str,
    ) -> dict[str, Any]:
        """Manager reviews a check-in — adds comment and marks reviewed."""
        if not comment or not comment.strip():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="A comment is required for the check-in review.",
            )

        doc = db.collection(COLLECTION).document(checkin_id).get()
        if not doc.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Check-in not found.",
            )
        checkin = doc.to_dict()
        checkin["id"] = doc.id

        # Verify manager owns the goal.
        goal_doc = db.collection(GOALS_COLLECTION).document(checkin["goal_id"]).get()
        if not goal_doc.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Linked goal sheet not found.",
            )
        goal = goal_doc.to_dict()
        if goal.get("manager_id") != manager_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only review check-ins for your team.",
            )

        now = datetime.now(timezone.utc)
        db.collection(COLLECTION).document(checkin_id).update({
            "status": "manager_reviewed",
            "manager_comment": comment.strip(),
            "manager_reviewed_at": now,
        })
        checkin["status"] = "manager_reviewed"
        checkin["manager_comment"] = comment.strip()
        checkin["manager_reviewed_at"] = now

        # Notify employee.
        create_notification(
            recipient_id=checkin["employee_id"],
            notification_type="checkin_reviewed",
            title=f"{checkin['quarter']} Check-In Reviewed",
            body="Your manager has reviewed your quarterly check-in.",
            related_entity_type="checkin",
            related_entity_id=checkin_id,
        )

        create_audit_log(
            action="checkin_reviewed",
            actor_id=manager_id,
            entity_id=checkin_id,
        )

        return checkin


checkin_service = CheckinService()
