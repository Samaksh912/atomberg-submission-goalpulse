"""Business logic for shared / cascaded goal operations."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import HTTPException, status

from app.models.shared_goal import SharedGoalCreate
from app.services.firebase_service import db
from app.services.notification_service import create_notification, create_audit_log


COLLECTION = "shared_goals"
GOALS_COLLECTION = "goals"


class SharedGoalService:
    """Create & manage shared KPIs across employee goal sheets."""

    # ── Create ────────────────────────────────────────────────────────────

    @staticmethod
    def create_shared_goal(
        creator_id: str,
        data: SharedGoalCreate,
    ) -> dict[str, Any]:
        """Push a shared KPI to multiple employee goal sheets.

        Steps:
        1. Validate owner is in recipients
        2. Create shared_goals document
        3. For each recipient: inject GoalItem into their goal sheet
        4. Update linkedGoalItemIds on the shared doc
        5. Notify recipients
        """
        if data.owner_employee_id not in data.recipient_ids:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="owner_employee_id must be one of recipient_ids.",
            )

        now = datetime.now(timezone.utc)
        shared_goal_id = str(uuid.uuid4())

        # Create the shared_goals document.
        shared_doc = {
            "id": shared_goal_id,
            "created_by": creator_id,
            "cycle_id": data.cycle_id,
            "thrust_area": data.thrust_area,
            "title": data.title,
            "description": data.description,
            "uom_type": data.uom_type,
            "target": data.target,
            "suggested_weightage": data.suggested_weightage,
            "recipient_ids": data.recipient_ids,
            "owner_employee_id": data.owner_employee_id,
            "linked_goal_item_ids": {},  # {employeeId: goalItemId}
            "created_at": now,
        }
        db.collection(COLLECTION).document(shared_goal_id).set(shared_doc)

        linked_map: dict[str, str] = {}
        updated_count = 0

        for emp_id in data.recipient_ids:
            goal_item_id = str(uuid.uuid4())

            # Build the shared GoalItem.
            new_item = {
                "goal_item_id": goal_item_id,
                "thrust_area": data.thrust_area,
                "title": data.title,
                "description": data.description,
                "uom_type": data.uom_type,
                "target": data.target,
                "weightage": data.suggested_weightage,
                "is_shared": True,
                "shared_goal_id": shared_goal_id,
                "is_locked": False,  # weightage editable
                "quarterly_data": {
                    "Q1": None, "Q2": None, "Q3": None, "Q4": None,
                },
                "ai_suggested": False,
            }

            # Find existing goal sheet for this employee + cycle.
            sheets = list(
                db.collection(GOALS_COLLECTION)
                .where("employee_id", "==", emp_id)
                .where("cycle_id", "==", data.cycle_id)
                .limit(1)
                .get()
            )

            if sheets:
                sheet_doc = sheets[0]
                sheet_data = sheet_doc.to_dict()
                existing_goals = sheet_data.get("goals", [])
                existing_goals.append(new_item)
                db.collection(GOALS_COLLECTION).document(sheet_doc.id).update({
                    "goals": existing_goals,
                    "total_weightage": sum(g["weightage"] for g in existing_goals),
                    "updated_at": now,
                })
            else:
                # Create a new draft goal sheet with just this item.
                sheet = {
                    "employee_id": emp_id,
                    "manager_id": creator_id,
                    "cycle_id": data.cycle_id,
                    "sheet_status": "draft",
                    "goals": [new_item],
                    "total_weightage": data.suggested_weightage,
                    "submitted_at": None,
                    "approved_at": None,
                    "manager_comment": None,
                    "created_at": now,
                    "updated_at": now,
                }
                db.collection(GOALS_COLLECTION).add(sheet)

            linked_map[emp_id] = goal_item_id
            updated_count += 1

            # Notify recipient.
            create_notification(
                recipient_id=emp_id,
                notification_type="shared_goal_added",
                title="A Shared Goal Has Been Added",
                body=f'Your manager added a shared goal: "{data.title}"',
                related_entity_type="shared_goal",
                related_entity_id=shared_goal_id,
            )

        # Write linkedGoalItemIds back to the shared_goals doc.
        db.collection(COLLECTION).document(shared_goal_id).update({
            "linked_goal_item_ids": linked_map,
        })
        shared_doc["linked_goal_item_ids"] = linked_map

        create_audit_log(
            action="shared_goal_created",
            actor_id=creator_id,
            entity_id=shared_goal_id,
            details={"recipients": data.recipient_ids, "title": data.title},
        )

        return {**shared_doc, "updated_count": updated_count}

    # ── List ──────────────────────────────────────────────────────────────

    @staticmethod
    def list_shared_goals(creator_id: str) -> list[dict[str, Any]]:
        """Return all shared goals created by this manager/admin."""
        docs = list(
            db.collection(COLLECTION)
            .where("created_by", "==", creator_id)
            .order_by("created_at", direction="DESCENDING")
            .get()
        )
        results = []
        for doc in docs:
            d = doc.to_dict()
            d["id"] = doc.id
            results.append(d)
        return results

    # ── Update Weightage ──────────────────────────────────────────────────

    @staticmethod
    def update_weightage(
        shared_goal_id: str,
        employee_id: str,
        weightage: float,
    ) -> None:
        """Allow a recipient to adjust their local weightage for the shared goal."""
        if weightage < 10:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Minimum weightage is 10%.",
            )

        # Fetch the shared goal to verify recipient.
        sg_doc = db.collection(COLLECTION).document(shared_goal_id).get()
        if not sg_doc.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Shared goal not found.",
            )
        sg = sg_doc.to_dict()
        if employee_id not in sg.get("recipient_ids", []):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not a recipient of this shared goal.",
            )

        goal_item_id = sg.get("linked_goal_item_ids", {}).get(employee_id)
        if not goal_item_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Linked goal item not found for this employee.",
            )

        # Find the employee's goal sheet.
        sheets = list(
            db.collection(GOALS_COLLECTION)
            .where("employee_id", "==", employee_id)
            .where("cycle_id", "==", sg["cycle_id"])
            .limit(1)
            .get()
        )
        if not sheets:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Goal sheet not found for this employee.",
            )
        sheet_doc = sheets[0]
        sheet_data = sheet_doc.to_dict()
        goals = sheet_data.get("goals", [])

        # Update the matching goal item.
        updated = False
        for g in goals:
            if g["goal_item_id"] == goal_item_id:
                g["weightage"] = weightage
                updated = True
                break

        if not updated:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Goal item not found in sheet.",
            )

        total = sum(g["weightage"] for g in goals)
        if abs(total - 100.0) > 0.01:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Total weightage must equal 100%. Current: {total}%.",
            )

        now = datetime.now(timezone.utc)
        db.collection(GOALS_COLLECTION).document(sheet_doc.id).update({
            "goals": goals,
            "total_weightage": total,
            "updated_at": now,
        })

    # ── Sync Actuals ──────────────────────────────────────────────────────

    @staticmethod
    def sync_actuals(
        shared_goal_id: str,
        owner_id: str,
        quarter: str,
        actual,
        progress_score: float,
    ) -> None:
        """Sync owner actuals to all linked recipient sheets via batch write."""
        sg_doc = db.collection(COLLECTION).document(shared_goal_id).get()
        if not sg_doc.exists:
            print(f"[sync_actuals] Shared goal {shared_goal_id} not found.")
            return

        sg = sg_doc.to_dict()
        if sg.get("owner_employee_id") != owner_id:
            print(f"[sync_actuals] {owner_id} is not the owner of {shared_goal_id}.")
            return

        linked = sg.get("linked_goal_item_ids", {})
        now = datetime.now(timezone.utc)

        batch = db.batch()
        sync_count = 0

        for emp_id, goal_item_id in linked.items():
            if emp_id == owner_id:
                continue  # Owner's own sheet is already updated by checkin_service.

            # Find that employee's goal sheet.
            sheets = list(
                db.collection(GOALS_COLLECTION)
                .where("employee_id", "==", emp_id)
                .where("cycle_id", "==", sg["cycle_id"])
                .limit(1)
                .get()
            )
            if not sheets:
                continue

            sheet_doc = sheets[0]
            sheet_data = sheet_doc.to_dict()
            goals = sheet_data.get("goals", [])

            for g in goals:
                if g["goal_item_id"] == goal_item_id:
                    qd = g.get("quarterly_data", {})
                    qd[quarter] = {
                        "actual": actual,
                        "status": "completed",
                        "progress_score": progress_score,
                        "synced_from_owner": True,
                        "last_synced_at": now,
                    }
                    g["quarterly_data"] = qd

            batch.update(
                db.collection(GOALS_COLLECTION).document(sheet_doc.id),
                {"goals": goals, "updated_at": now},
            )
            sync_count += 1

        batch.commit()
        print(
            f"[sync_actuals] Synced actuals for shared_goal {shared_goal_id} "
            f"to {sync_count} recipients."
        )


shared_goal_service = SharedGoalService()
