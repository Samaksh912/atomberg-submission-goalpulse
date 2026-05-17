"""Business logic for Goal Sheet lifecycle operations."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import HTTPException, status

from app.models.goal import GoalItemCreate, GoalSheetCreate
from app.services.firebase_service import db


class GoalService:
    """Encapsulates all goal-sheet operations against Firestore."""

    COLLECTION = "goals"

    # ── Validation ────────────────────────────────────────────────────────

    @staticmethod
    def validate_goals(goals: list[GoalItemCreate]) -> None:
        """Raise ValueError if business rules are violated."""
        if len(goals) > 8:
            raise ValueError("Maximum 8 goals per sheet.")
        if len(goals) < 1:
            raise ValueError("At least 1 goal is required.")

        total = sum(g.weightage for g in goals)
        if abs(total - 100.0) > 0.01:
            raise ValueError(
                f"Total weightage must equal 100%. Current: {total}%"
            )

        for i, g in enumerate(goals, 1):
            if g.weightage < 10:
                raise ValueError(
                    f"Goal {i} ('{g.title}') has weightage {g.weightage}%. "
                    f"Minimum is 10%."
                )

    # ── Read ──────────────────────────────────────────────────────────────

    @staticmethod
    def get_my_goals(employee_id: str, cycle_id: str) -> Optional[dict[str, Any]]:
        """Return the goal sheet for *employee_id* + *cycle_id*, or None."""
        query = (
            db.collection(GoalService.COLLECTION)
            .where("employee_id", "==", employee_id)
            .where("cycle_id", "==", cycle_id)
            .limit(1)
            .get()
        )
        docs = list(query)
        if not docs:
            return None
        doc = docs[0]
        data = doc.to_dict()
        data["id"] = doc.id
        return data

    @staticmethod
    def get_goal_by_id(goal_id: str) -> Optional[dict[str, Any]]:
        """Return a single goal sheet by its document ID."""
        doc = db.collection(GoalService.COLLECTION).document(goal_id).get()
        if not doc.exists:
            return None
        data = doc.to_dict()
        data["id"] = doc.id
        return data

    # ── Create ────────────────────────────────────────────────────────────

    @staticmethod
    def create_goal_sheet(
        employee_id: str,
        manager_id: Optional[str],
        data: GoalSheetCreate,
    ) -> str:
        """Persist a new goal sheet and return the Firestore document ID."""
        GoalService.validate_goals(data.goals)

        # Check for existing sheet in this cycle.
        existing = GoalService.get_my_goals(employee_id, data.cycle_id)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Goal sheet already exists for this cycle. Use PUT to update.",
            )

        now = datetime.now(timezone.utc)
        goals_list = []
        for g in data.goals:
            goals_list.append({
                "goal_item_id": str(uuid.uuid4()),
                "thrust_area": g.thrust_area,
                "title": g.title,
                "description": g.description,
                "uom_type": g.uom_type,
                "target": g.target,
                "weightage": g.weightage,
                "is_shared": False,
                "shared_goal_id": None,
                "is_locked": False,
                "quarterly_data": {"Q1": None, "Q2": None, "Q3": None, "Q4": None},
                "ai_suggested": False,
            })

        doc_data = {
            "employee_id": employee_id,
            "manager_id": manager_id,
            "cycle_id": data.cycle_id,
            "sheet_status": "draft",
            "goals": goals_list,
            "total_weightage": sum(g.weightage for g in data.goals),
            "submitted_at": None,
            "approved_at": None,
            "manager_comment": None,
            "created_at": now,
            "updated_at": now,
        }

        _, ref = db.collection(GoalService.COLLECTION).add(doc_data)
        return ref.id

    # ── Update ────────────────────────────────────────────────────────────

    @staticmethod
    def update_goal_sheet(
        goal_id: str,
        employee_id: str,
        data: GoalSheetCreate,
    ) -> None:
        """Update an existing draft / returned goal sheet."""
        existing = GoalService.get_goal_by_id(goal_id)
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Goal sheet not found.",
            )
        if existing["employee_id"] != employee_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only edit your own goal sheet.",
            )
        if existing["sheet_status"] not in ("draft", "returned"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Cannot edit a goal sheet with status '{existing['sheet_status']}'.",
            )

        GoalService.validate_goals(data.goals)

        now = datetime.now(timezone.utc)

        # Preserve existing goal_item_ids where possible (match by index).
        old_goals = existing.get("goals", [])
        goals_list = []
        for i, g in enumerate(data.goals):
            item_id = (
                old_goals[i]["goal_item_id"]
                if i < len(old_goals)
                else str(uuid.uuid4())
            )
            # Preserve shared-goal flags from original if present.
            old = old_goals[i] if i < len(old_goals) else {}
            goals_list.append({
                "goal_item_id": item_id,
                "thrust_area": g.thrust_area,
                "title": g.title,
                "description": g.description,
                "uom_type": g.uom_type,
                "target": g.target,
                "weightage": g.weightage,
                "is_shared": old.get("is_shared", False),
                "shared_goal_id": old.get("shared_goal_id"),
                "is_locked": False,
                "quarterly_data": old.get(
                    "quarterly_data",
                    {"Q1": None, "Q2": None, "Q3": None, "Q4": None},
                ),
                "ai_suggested": old.get("ai_suggested", False),
            })

        db.collection(GoalService.COLLECTION).document(goal_id).update({
            "goals": goals_list,
            "total_weightage": sum(g.weightage for g in data.goals),
            "updated_at": now,
        })

    # ── Submit ────────────────────────────────────────────────────────────

    @staticmethod
    def submit_goal_sheet(goal_id: str, employee_id: str) -> None:
        """Move a draft / returned sheet to 'submitted' status."""
        existing = GoalService.get_goal_by_id(goal_id)
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Goal sheet not found.",
            )
        if existing["employee_id"] != employee_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only submit your own goal sheet.",
            )
        if existing["sheet_status"] not in ("draft", "returned"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Cannot submit a goal sheet with status '{existing['sheet_status']}'.",
            )

        # Re-validate before submit.
        goals_data = existing.get("goals", [])
        items = [
            GoalItemCreate(
                thrust_area=g["thrust_area"],
                title=g["title"],
                description=g.get("description", ""),
                uom_type=g["uom_type"],
                target=g["target"],
                weightage=g["weightage"],
            )
            for g in goals_data
        ]
        GoalService.validate_goals(items)

        now = datetime.now(timezone.utc)
        db.collection(GoalService.COLLECTION).document(goal_id).update({
            "sheet_status": "submitted",
            "submitted_at": now,
            "updated_at": now,
        })
        # TODO: trigger notification to manager

    # ── Team goals (manager view) ─────────────────────────────────────────

    @staticmethod
    def get_team_goals(
        manager_id: str,
        cycle_id: str,
        status_filter: Optional[str] = None,
    ) -> list[dict[str, Any]]:
        """Return all goal sheets where managerId == manager_id."""
        query = (
            db.collection(GoalService.COLLECTION)
            .where("manager_id", "==", manager_id)
            .where("cycle_id", "==", cycle_id)
        )
        if status_filter:
            query = query.where("sheet_status", "==", status_filter)

        docs = list(query.get())
        results = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            # Join employee profile info.
            emp_id = data.get("employee_id", "")
            emp_doc = db.collection("users").document(emp_id).get()
            if emp_doc.exists:
                emp = emp_doc.to_dict()
                data["employee_name"] = emp.get("display_name", "")
                data["employee_email"] = emp.get("email", "")
                data["employee_department"] = emp.get("department", "")
            else:
                data["employee_name"] = ""
                data["employee_email"] = ""
                data["employee_department"] = ""
            results.append(data)
        return results

    # ── Approve ───────────────────────────────────────────────────────────

    @staticmethod
    def approve_goal_sheet(
        goal_id: str,
        manager_id: str,
        comment: Optional[str] = None,
        edited_goals: Optional[list[dict]] = None,
    ) -> None:
        """Approve a submitted goal sheet — locks all items."""
        from app.services.notification_service import create_notification, create_audit_log

        existing = GoalService.get_goal_by_id(goal_id)
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Goal sheet not found.",
            )
        if existing.get("manager_id") != manager_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only approve goals for your direct reports.",
            )
        if existing["sheet_status"] != "submitted":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Cannot approve a goal sheet with status '{existing['sheet_status']}'.",
            )

        goals = existing.get("goals", [])

        # Apply inline edits from the manager if provided.
        if edited_goals:
            edit_map = {eg["goalItemId"]: eg for eg in edited_goals}
            for g in goals:
                edit = edit_map.get(g["goal_item_id"])
                if edit:
                    if "target" in edit:
                        g["target"] = edit["target"]
                    if "weightage" in edit:
                        g["weightage"] = edit["weightage"]

        # Re-validate after edits.
        items = [
            GoalItemCreate(
                thrust_area=g["thrust_area"],
                title=g["title"],
                description=g.get("description", ""),
                uom_type=g["uom_type"],
                target=g["target"],
                weightage=g["weightage"],
            )
            for g in goals
        ]
        GoalService.validate_goals(items)

        # Lock all items.
        for g in goals:
            g["is_locked"] = True

        now = datetime.now(timezone.utc)
        db.collection(GoalService.COLLECTION).document(goal_id).update({
            "goals": goals,
            "sheet_status": "approved",
            "approved_at": now,
            "approved_by": manager_id,
            "manager_comment": comment,
            "total_weightage": sum(g["weightage"] for g in goals),
            "updated_at": now,
        })

        # Audit log.
        create_audit_log(
            action="goal_approved",
            actor_id=manager_id,
            entity_id=goal_id,
        )

        # Notification to employee.
        employee_id = existing["employee_id"]
        create_notification(
            recipient_id=employee_id,
            notification_type="goal_approved",
            title="Goal Sheet Approved",
            body="Your goal sheet has been approved by your manager.",
            related_entity_type="goal_sheet",
            related_entity_id=goal_id,
        )

    # ── Return ────────────────────────────────────────────────────────────

    @staticmethod
    def return_goal_sheet(
        goal_id: str,
        manager_id: str,
        comment: str,
    ) -> None:
        """Return a submitted goal sheet for rework."""
        from app.services.notification_service import create_notification, create_audit_log

        if not comment or not comment.strip():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="A comment is required when returning a goal sheet.",
            )

        existing = GoalService.get_goal_by_id(goal_id)
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Goal sheet not found.",
            )
        if existing.get("manager_id") != manager_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only return goals for your direct reports.",
            )
        if existing["sheet_status"] != "submitted":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Cannot return a goal sheet with status '{existing['sheet_status']}'.",
            )

        now = datetime.now(timezone.utc)
        db.collection(GoalService.COLLECTION).document(goal_id).update({
            "sheet_status": "returned",
            "manager_comment": comment.strip(),
            "updated_at": now,
        })

        # Audit log.
        create_audit_log(
            action="goal_returned",
            actor_id=manager_id,
            entity_id=goal_id,
            details={"comment": comment.strip()},
        )

        # Notification to employee.
        employee_id = existing["employee_id"]
        truncated = comment.strip()[:80]
        create_notification(
            recipient_id=employee_id,
            notification_type="goal_returned",
            title="Goal Sheet Returned",
            body=f'Your manager returned your goals: "{truncated}"',
            related_entity_type="goal_sheet",
            related_entity_id=goal_id,
        )

    # ── Unlock Goal Item (admin only) ─────────────────────────────────────

    @staticmethod
    def unlock_goal_item(
        goal_id: str,
        goal_item_id: str,
        admin_id: str,
        reason: str,
    ) -> dict:
        """Unlock a single locked goal item with a mandatory reason.

        Always creates an audit_log entry — this is non-negotiable.
        """
        if not reason or not reason.strip():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="A reason is required to unlock a goal item.",
            )

        doc = db.collection(GoalService.COLLECTION).document(goal_id).get()
        if not doc.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Goal sheet not found.",
            )
        goal = doc.to_dict()

        goals = goal.get("goals", [])
        unlocked = False
        goal_title = ""
        for g in goals:
            if g["goal_item_id"] == goal_item_id:
                g["is_locked"] = False
                unlocked = True
                goal_title = g.get("title", "")
                break

        if not unlocked:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Goal item {goal_item_id} not found in sheet.",
            )

        now = datetime.now(timezone.utc)
        db.collection(GoalService.COLLECTION).document(goal_id).update({
            "goals": goals,
            "updated_at": now,
        })

        # MANDATORY audit log.
        from app.services.notification_service import create_notification, create_audit_log
        create_audit_log(
            action="goal_unlocked",
            actor_id=admin_id,
            entity_id=goal_item_id,
            details={
                "actor_role": "admin",
                "target_type": "goal_item",
                "target_id": goal_item_id,
                "employee_id": goal.get("employee_id"),
                "goal_id": goal_id,
                "field_changed": "is_locked",
                "old_value": True,
                "new_value": False,
                "reason": reason.strip(),
                "goal_title": goal_title,
            },
        )

        # Notify employee.
        employee_id = goal.get("employee_id", "")
        if employee_id:
            create_notification(
                recipient_id=employee_id,
                notification_type="goal_unlocked",
                title="A Goal Item Has Been Unlocked",
                body=f'Admin unlocked "{goal_title}" on your goal sheet.',
                related_entity_type="goal_item",
                related_entity_id=goal_item_id,
            )

        return {"goalId": goal_id, "goalItemId": goal_item_id, "unlocked": True}


goal_service = GoalService()
