"""Admin panel business logic — users, cycles, audit logs."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import HTTPException, status

from app.models.cycle import CycleCreate, CycleUpdate
from app.services.firebase_service import auth as firebase_auth, db
from app.services.notification_service import create_audit_log


USERS_COLLECTION = "users"
CYCLES_COLLECTION = "cycles"
AUDIT_COLLECTION = "audit_logs"
GOALS_COLLECTION = "goals"


class AdminService:
    """All admin-level operations."""

    # ── Users ──────────────────────────────────────────────────────────────

    @staticmethod
    def get_users(
        search: str = "",
        role_filter: str = "",
        page: int = 1,
        page_size: int = 20,
    ) -> dict[str, Any]:
        """Return paginated users, optionally filtered."""
        query = db.collection(USERS_COLLECTION)

        # Firestore doesn't support LIKE; we fetch and filter in Python.
        docs = list(query.order_by("display_name").get())
        users = []
        for doc in docs:
            d = doc.to_dict()
            d["id"] = doc.id

            if role_filter and d.get("role") != role_filter:
                continue

            if search:
                s = search.lower()
                if (
                    s not in (d.get("display_name") or "").lower()
                    and s not in (d.get("email") or "").lower()
                    and s not in (d.get("department") or "").lower()
                ):
                    continue
            users.append(d)

        total = len(users)
        start = (page - 1) * page_size
        paginated = users[start : start + page_size]
        return {
            "total": total,
            "page": page,
            "page_size": page_size,
            "users": paginated,
        }

    @staticmethod
    def create_user(data: dict) -> dict[str, Any]:
        """Create Firebase Auth user and Firestore profile."""
        email = data.get("email", "").strip()
        password = data.get("password", "").strip()
        display_name = data.get("display_name", "").strip()

        if not email or not password:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="email and password are required.",
            )

        try:
            fb_user = firebase_auth.create_user(
                email=email,
                password=password,
                display_name=display_name,
            )
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Firebase Auth error: {exc}",
            )

        now = datetime.now(timezone.utc)
        profile = {
            "email": email,
            "display_name": display_name,
            "role": data.get("role", "employee"),
            "manager_id": data.get("manager_id"),
            "department": data.get("department", ""),
            "designation": data.get("designation", ""),
            "is_active": True,
            "created_at": now,
            "updated_at": now,
        }
        db.collection(USERS_COLLECTION).document(fb_user.uid).set(profile)
        profile["id"] = fb_user.uid
        return profile

    @staticmethod
    def update_user(user_id: str, data: dict) -> dict[str, Any]:
        """Update a Firestore user profile. Role changes require special care."""
        doc = db.collection(USERS_COLLECTION).document(user_id).get()
        if not doc.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found.",
            )

        allowed_fields = {
            "display_name", "role", "manager_id",
            "department", "designation", "is_active",
        }
        update = {k: v for k, v in data.items() if k in allowed_fields}
        update["updated_at"] = datetime.now(timezone.utc)

        db.collection(USERS_COLLECTION).document(user_id).update(update)
        updated = doc.to_dict()
        updated.update(update)
        updated["id"] = user_id
        return updated

    # ── Audit Logs ─────────────────────────────────────────────────────────

    @staticmethod
    def get_audit_logs(
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        actor_id: Optional[str] = None,
        action_filter: Optional[str] = None,
        page: int = 1,
        page_size: int = 50,
    ) -> dict[str, Any]:
        """Return paginated audit logs with optional filters."""
        query = db.collection(AUDIT_COLLECTION).order_by(
            "timestamp", direction="DESCENDING"
        )

        if start_date:
            query = query.where(
                "timestamp", ">=", datetime.fromisoformat(start_date)
            )
        if end_date:
            query = query.where(
                "timestamp", "<=", datetime.fromisoformat(end_date)
            )
        if actor_id:
            query = query.where("actor_id", "==", actor_id)
        if action_filter:
            query = query.where("action", "==", action_filter)

        docs = list(query.get())
        logs = []
        for doc in docs:
            d = doc.to_dict()
            d["id"] = doc.id
            logs.append(d)

        total = len(logs)
        start = (page - 1) * page_size
        paginated = logs[start : start + page_size]
        return {
            "total": total,
            "page": page,
            "page_size": page_size,
            "logs": paginated,
        }

    # ── Cycles ─────────────────────────────────────────────────────────────

    @staticmethod
    def _phase_to_dict(phase) -> dict:
        return {
            "open_date": phase.open_date,
            "close_date": phase.close_date,
        }

    @staticmethod
    def create_cycle(admin_id: str, data: CycleCreate) -> dict[str, Any]:
        """Create a new performance cycle document."""
        now = datetime.now(timezone.utc)
        cycle_id = f"cycle_{data.year}"

        doc_data = {
            "id": cycle_id,
            "year": data.year,
            "label": data.label or f"FY {data.year}",
            "is_active": False,
            "goal_setting": AdminService._phase_to_dict(data.goal_setting),
            "q1": AdminService._phase_to_dict(data.q1),
            "q2": AdminService._phase_to_dict(data.q2),
            "q3": AdminService._phase_to_dict(data.q3),
            "q4": AdminService._phase_to_dict(data.q4),
            "created_by": admin_id,
            "created_at": now,
            "updated_at": now,
        }
        db.collection(CYCLES_COLLECTION).document(cycle_id).set(doc_data)
        create_audit_log(
            action="cycle_created",
            actor_id=admin_id,
            entity_id=cycle_id,
            details={"year": data.year},
        )
        return doc_data

    @staticmethod
    def update_cycle(
        cycle_id: str, admin_id: str, data: CycleUpdate
    ) -> dict[str, Any]:
        """Partially update a cycle."""
        doc = db.collection(CYCLES_COLLECTION).document(cycle_id).get()
        if not doc.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Cycle not found.",
            )

        update: dict = {"updated_at": datetime.now(timezone.utc)}
        if data.year is not None:
            update["year"] = data.year
        if data.label is not None:
            update["label"] = data.label
        for phase in ("goal_setting", "q1", "q2", "q3", "q4"):
            val = getattr(data, phase)
            if val is not None:
                update[phase] = AdminService._phase_to_dict(val)

        db.collection(CYCLES_COLLECTION).document(cycle_id).update(update)
        create_audit_log(
            action="cycle_updated",
            actor_id=admin_id,
            entity_id=cycle_id,
        )
        updated = doc.to_dict()
        updated.update(update)
        updated["id"] = cycle_id
        return updated

    @staticmethod
    def get_active_cycle() -> Optional[dict[str, Any]]:
        """Return the active cycle, or None."""
        docs = list(
            db.collection(CYCLES_COLLECTION)
            .where("is_active", "==", True)
            .limit(1)
            .get()
        )
        if not docs:
            return None
        d = docs[0].to_dict()
        d["id"] = docs[0].id
        return d

    @staticmethod
    def list_cycles() -> list[dict[str, Any]]:
        """Return all cycles ordered by year descending."""
        docs = list(
            db.collection(CYCLES_COLLECTION)
            .order_by("year", direction="DESCENDING")
            .get()
        )
        results = []
        for doc in docs:
            d = doc.to_dict()
            d["id"] = doc.id
            results.append(d)
        return results

    @staticmethod
    def activate_cycle(cycle_id: str, admin_id: str) -> dict[str, Any]:
        """Activate a cycle, deactivating all others."""
        doc = db.collection(CYCLES_COLLECTION).document(cycle_id).get()
        if not doc.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Cycle not found.",
            )

        # Deactivate all cycles.
        all_cycles = list(db.collection(CYCLES_COLLECTION).get())
        batch = db.batch()
        for c in all_cycles:
            if c.id != cycle_id:
                batch.update(
                    db.collection(CYCLES_COLLECTION).document(c.id),
                    {"is_active": False},
                )
        batch.commit()

        # Activate this one.
        now = datetime.now(timezone.utc)
        db.collection(CYCLES_COLLECTION).document(cycle_id).update({
            "is_active": True,
            "activated_at": now,
            "activated_by": admin_id,
        })
        create_audit_log(
            action="cycle_activated",
            actor_id=admin_id,
            entity_id=cycle_id,
        )
        updated = doc.to_dict()
        updated["is_active"] = True
        updated["id"] = cycle_id
        return updated

    # ── Stats (for dashboard) ─────────────────────────────────────────────

    @staticmethod
    def get_org_stats() -> dict[str, Any]:
        """Return org-wide counts for the admin dashboard."""
        users = list(db.collection(USERS_COLLECTION).get())
        total_employees = sum(
            1 for u in users if u.to_dict().get("role") == "employee"
        )

        goals = list(db.collection(GOALS_COLLECTION).get())
        goals_submitted = sum(
            1 for g in goals
            if g.to_dict().get("sheet_status") not in ("draft",)
        )
        goals_approved = sum(
            1 for g in goals
            if g.to_dict().get("sheet_status") in ("approved", "locked")
        )
        goals_pending = sum(
            1 for g in goals
            if g.to_dict().get("sheet_status") == "submitted"
        )

        return {
            "total_employees": total_employees,
            "goals_submitted": goals_submitted,
            "goals_approved": goals_approved,
            "pending_approvals": goals_pending,
            "checkin_completion_rate": 0,  # Wired in Phase 9.
        }


admin_service = AdminService()
