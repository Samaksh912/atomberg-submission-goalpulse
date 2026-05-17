"""Analytics aggregation service — all queries run over Firestore, aggregated in Python."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Optional

from app.services.firebase_service import db

GOALS = "goals"
CHECKINS = "checkins"
USERS = "users"


def _safe_float(v) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def _user_map() -> dict[str, dict]:
    """Return uid → user dict for all users."""
    docs = db.collection(USERS).get()
    return {d.id: d.to_dict() for d in docs}


def _goals_for(
    requester_id: str,
    role: str,
    cycle_id: str,
) -> list[dict]:
    """Return goal sheet documents scoped to the requester."""
    query = db.collection(GOALS).where("cycle_id", "==", cycle_id)
    if role == "manager":
        query = query.where("manager_id", "==", requester_id)
    docs = list(query.get())
    results = []
    for d in docs:
        obj = d.to_dict()
        obj["id"] = d.id
        results.append(obj)
    return results


def _checkins_for_goals(goal_ids: list[str]) -> list[dict]:
    """Fetch all check-ins for a list of goal IDs."""
    all_checkins = []
    # Firestore 'in' clause supports up to 30 items; chunk if needed.
    for i in range(0, len(goal_ids), 30):
        chunk = goal_ids[i : i + 30]
        docs = list(
            db.collection(CHECKINS).where("goal_id", "in", chunk).get()
        )
        for d in docs:
            obj = d.to_dict()
            obj["id"] = d.id
            all_checkins.append(obj)
    return all_checkins


class AnalyticsService:
    """All analytics aggregations."""

    # ── Completion Dashboard ───────────────────────────────────────────────

    @staticmethod
    def get_completion_dashboard(
        requester_id: str,
        role: str,
        cycle_id: str,
        quarter: Optional[str] = None,
    ) -> dict[str, Any]:
        """Per-employee goal & check-in completion matrix."""
        goals = _goals_for(requester_id, role, cycle_id)
        if not goals:
            return {"completionRate": 0.0, "employees": []}

        goal_ids = [g["id"] for g in goals]
        checkins = _checkins_for_goals(goal_ids)
        users = _user_map()

        # Index checkins by (goal_id, quarter).
        checkin_index: dict[tuple, bool] = {}
        for c in checkins:
            checkin_index[(c["goal_id"], c.get("quarter", ""))] = True

        quarters = ["Q1", "Q2", "Q3", "Q4"]
        rows = []
        completed_checkin_count = 0

        for g in goals:
            uid = g.get("employee_id", "")
            user = users.get(uid, {})
            checkins_done: dict[str, bool] = {}
            for q in quarters:
                done = checkin_index.get((g["id"], q), False)
                checkins_done[q] = done

            target_q = quarter or quarters[-1]
            if checkins_done.get(target_q):
                completed_checkin_count += 1

            rows.append(
                {
                    "userId": uid,
                    "name": user.get("display_name") or user.get("email", uid),
                    "department": user.get("department", ""),
                    "goalSubmitted": g.get("sheet_status") not in ("draft",),
                    "goalApproved": g.get("sheet_status") in ("approved", "locked"),
                    "checkinsCompleted": checkins_done,
                }
            )

        rate = (completed_checkin_count / len(goals) * 100) if goals else 0.0
        return {"completionRate": round(rate, 1), "employees": rows}

    # ── QoQ Trends ────────────────────────────────────────────────────────

    @staticmethod
    def get_qoq_trends(
        requester_id: str,
        role: str,
        cycle_id: str,
        employee_id: Optional[str] = None,
        department: Optional[str] = None,
    ) -> dict[str, Any]:
        """Average progress scores per quarter."""
        goals = _goals_for(requester_id, role, cycle_id)

        # Optional extra filters.
        users = _user_map()
        if employee_id:
            goals = [g for g in goals if g.get("employee_id") == employee_id]
        if department:
            goals = [
                g for g in goals
                if users.get(g.get("employee_id", ""), {}).get("department") == department
            ]

        if not goals:
            return {
                "quarters": ["Q1", "Q2", "Q3", "Q4"],
                "avgScores": [0.0, 0.0, 0.0, 0.0],
                "goalCompletionRates": [0.0, 0.0, 0.0, 0.0],
            }

        goal_ids = [g["id"] for g in goals]
        checkins = _checkins_for_goals(goal_ids)

        quarters = ["Q1", "Q2", "Q3", "Q4"]
        q_scores: dict[str, list[float]] = {q: [] for q in quarters}
        q_completed: dict[str, int] = {q: 0 for q in quarters}
        q_total = len(goals)

        for c in checkins:
            q = c.get("quarter", "")
            if q not in quarters:
                continue
            actuals = c.get("actuals", [])
            scores = [_safe_float(a.get("progress_score", 0)) for a in actuals]
            if scores:
                q_scores[q].append(sum(scores) / len(scores))
            q_completed[q] = q_completed.get(q, 0) + 1

        avg_scores = [
            round(sum(q_scores[q]) / len(q_scores[q]), 1) if q_scores[q] else 0.0
            for q in quarters
        ]
        completion_rates = [
            round(q_completed[q] / q_total * 100, 1) if q_total else 0.0
            for q in quarters
        ]

        return {
            "quarters": quarters,
            "avgScores": avg_scores,
            "goalCompletionRates": completion_rates,
        }

    # ── Manager Effectiveness (admin only) ────────────────────────────────

    @staticmethod
    def get_manager_effectiveness(cycle_id: str) -> dict[str, Any]:
        """Per-manager aggregated metrics."""
        all_goals = list(db.collection(GOALS).where("cycle_id", "==", cycle_id).get())
        users = _user_map()

        # Group goals by manager.
        mgr_goals: dict[str, list[dict]] = {}
        for d in all_goals:
            obj = d.to_dict()
            obj["id"] = d.id
            mgr_id = obj.get("manager_id", "")
            if not mgr_id:
                continue
            mgr_goals.setdefault(mgr_id, []).append(obj)

        if not mgr_goals:
            return {"managers": []}

        all_goal_ids = [d.id for d in all_goals]
        all_checkins = _checkins_for_goals(all_goal_ids)
        checkin_by_goal: dict[str, list[dict]] = {}
        for c in all_checkins:
            checkin_by_goal.setdefault(c["goal_id"], []).append(c)

        results = []
        for mgr_id, goals in mgr_goals.items():
            mgr_user = users.get(mgr_id, {})
            mgr_name = mgr_user.get("display_name") or mgr_user.get("email", mgr_id)

            total_goals = len(goals)
            checkins_done = sum(1 for g in goals if checkin_by_goal.get(g["id"]))

            # Avg team progress score (from all actuals across all check-ins).
            all_scores: list[float] = []
            for g in goals:
                for c in checkin_by_goal.get(g["id"], []):
                    for a in c.get("actuals", []):
                        s = _safe_float(a.get("progress_score", 0))
                        if s > 0:
                            all_scores.append(s)

            avg_score = round(sum(all_scores) / len(all_scores), 1) if all_scores else 0.0
            checkin_rate = round(checkins_done / total_goals * 100, 1) if total_goals else 0.0

            # Approval turnaround (approved_at - submitted_at).
            turnarounds = []
            for g in goals:
                submitted = g.get("submitted_at")
                approved = g.get("approved_at")
                if submitted and approved:
                    try:
                        diff = (
                            approved.replace(tzinfo=timezone.utc)
                            - submitted.replace(tzinfo=timezone.utc)
                        ).days
                        turnarounds.append(max(0, diff))
                    except Exception:
                        pass

            avg_turnaround = round(sum(turnarounds) / len(turnarounds), 1) if turnarounds else 0.0

            results.append(
                {
                    "managerId": mgr_id,
                    "name": mgr_name,
                    "checkinRate": checkin_rate,
                    "avgScore": avg_score,
                    "avgTurnaroundDays": avg_turnaround,
                    "teamSize": total_goals,
                }
            )

        results.sort(key=lambda x: x["checkinRate"], reverse=True)
        return {"managers": results}

    # ── Goal Distribution ─────────────────────────────────────────────────

    @staticmethod
    def get_goal_distribution(
        requester_id: str,
        role: str,
        cycle_id: str,
    ) -> dict[str, Any]:
        """Count goals by thrust area, UoM type, and status."""
        goals = _goals_for(requester_id, role, cycle_id)

        by_thrust: dict[str, int] = {}
        by_uom: dict[str, int] = {}
        by_status: dict[str, int] = {}

        for g in goals:
            status = g.get("sheet_status", "draft")
            by_status[status] = by_status.get(status, 0) + 1
            for item in g.get("goals", []):
                thrust = item.get("thrust_area", "Other")
                uom = item.get("uom_type", "unknown")
                by_thrust[thrust] = by_thrust.get(thrust, 0) + 1
                by_uom[uom] = by_uom.get(uom, 0) + 1

        return {
            "byThrustArea": by_thrust,
            "byUomType": by_uom,
            "byStatus": by_status,
        }


analytics_service = AnalyticsService()
