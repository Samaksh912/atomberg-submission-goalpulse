#!/usr/bin/env python3
"""Seed GoalPulse with demo data for hackathon presentation.

Run once:  python seed_demo_data.py
"""

import uuid
from datetime import datetime, timedelta, timezone

# ── Bootstrap Firebase before anything else ──────────────────────────────────
from app.services.firebase_service import db, auth  # noqa: E402

NOW = datetime.now(timezone.utc)
CYCLE_ID = "cycle_2025"

# ── Helpers ──────────────────────────────────────────────────────────────────

def _id() -> str:
    return uuid.uuid4().hex[:20]


def _ensure_user(email: str, password: str, display_name: str) -> str:
    """Create or fetch Firebase Auth user; return uid."""
    try:
        user = auth.get_user_by_email(email)
        print(f"  ✓ Found existing user {email} ({user.uid})")
        return user.uid
    except auth.UserNotFoundError:
        user = auth.create_user(
            email=email,
            password=password,
            display_name=display_name,
        )
        print(f"  ✓ Created user {email} ({user.uid})")
        return user.uid


def _set_claims(uid: str, role: str):
    auth.set_custom_user_claims(uid, {"role": role})
    print(f"    → Set claims: role={role}")


# ── 1. Users ─────────────────────────────────────────────────────────────────

print("\n═══ 1. Creating Users ═══")

admin_uid = _ensure_user("admin@demo.com", "Demo@1234", "Priya Sharma")
_set_claims(admin_uid, "admin")

manager_uid = _ensure_user("manager@demo.com", "Demo@1234", "Rahul Mehta")
_set_claims(manager_uid, "manager")

emp1_uid = _ensure_user("emp1@demo.com", "Demo@1234", "Ananya Iyer")
_set_claims(emp1_uid, "employee")

emp2_uid = _ensure_user("emp2@demo.com", "Demo@1234", "Karthik Nair")
_set_claims(emp2_uid, "employee")

emp3_uid = _ensure_user("emp3@demo.com", "Demo@1234", "Deepa Raj")
_set_claims(emp3_uid, "employee")

# ── 2. Firestore user profiles ──────────────────────────────────────────────

print("\n═══ 2. Writing User Profiles ═══")

users_data = {
    admin_uid: {
        "uid": admin_uid,
        "email": "admin@demo.com",
        "displayName": "Priya Sharma",
        "display_name": "Priya Sharma",
        "role": "admin",
        "department": "HR",
        "designation": "HR Manager",
        "managerId": None,
        "createdAt": NOW,
    },
    manager_uid: {
        "uid": manager_uid,
        "email": "manager@demo.com",
        "displayName": "Rahul Mehta",
        "display_name": "Rahul Mehta",
        "role": "manager",
        "department": "Sales",
        "designation": "Sales Manager",
        "managerId": None,
        "createdAt": NOW,
    },
    emp1_uid: {
        "uid": emp1_uid,
        "email": "emp1@demo.com",
        "displayName": "Ananya Iyer",
        "display_name": "Ananya Iyer",
        "role": "employee",
        "department": "Sales",
        "designation": "Sales Executive",
        "managerId": manager_uid,
        "createdAt": NOW,
    },
    emp2_uid: {
        "uid": emp2_uid,
        "email": "emp2@demo.com",
        "displayName": "Karthik Nair",
        "display_name": "Karthik Nair",
        "role": "employee",
        "department": "Sales",
        "designation": "Business Dev",
        "managerId": manager_uid,
        "createdAt": NOW,
    },
    emp3_uid: {
        "uid": emp3_uid,
        "email": "emp3@demo.com",
        "displayName": "Deepa Raj",
        "display_name": "Deepa Raj",
        "role": "employee",
        "department": "Sales",
        "designation": "Account Manager",
        "managerId": manager_uid,
        "createdAt": NOW,
    },
}

for uid, data in users_data.items():
    db.collection("users").document(uid).set(data, merge=True)
    print(f"  ✓ {data['displayName']} ({data['role']})")

# ── 3. Active Cycle ──────────────────────────────────────────────────────────

print("\n═══ 3. Creating Active Cycle ═══")

cycle_data = {
    "year": 2025,
    "isActive": True,
    "phases": {
        "goalSetting": {
            "openDate": "2025-05-01",
            "closeDate": "2025-06-30",
        },
        "Q1": {
            "openDate": "2025-07-01",
            "closeDate": "2025-07-31",
        },
        "Q2": {
            "openDate": "2025-10-01",
            "closeDate": "2025-10-31",
        },
        "Q3": {
            "openDate": "2026-01-01",
            "closeDate": "2026-01-31",
        },
        "Q4": {
            "openDate": "2026-03-01",
            "closeDate": "2026-04-30",
        },
    },
    "createdAt": NOW,
}

db.collection("cycles").document(CYCLE_ID).set(cycle_data, merge=True)
print("  ✓ cycle_2025 (active)")

# ── 4. emp1 Goal Sheet (locked, with Q1 actuals) ────────────────────────────

print("\n═══ 4. Seeding emp1 Goal Sheet (locked + Q1 actuals) ═══")

emp1_goal_id = f"goal_{emp1_uid[:12]}"
emp1_goals = [
    {
        "goal_item_id": _id(),
        "title": "Achieve Sales Revenue of ₹50L",
        "description": "Drive quarterly revenue through new client acquisition and upselling.",
        "thrustArea": "Revenue Growth",
        "uom_type": "numeric_min",
        "target": 5000000,
        "weightage": 30,
        "isShared": False,
    },
    {
        "goal_item_id": _id(),
        "title": "Reduce Customer Churn to < 5%",
        "description": "Maintain churn below 5% through proactive account management.",
        "thrustArea": "Customer Experience",
        "uom_type": "percent_max",
        "target": 5,
        "weightage": 25,
        "isShared": False,
    },
    {
        "goal_item_id": _id(),
        "title": "Complete 3 Product Training Modules",
        "description": "Upskill on new product lines to improve sales conversations.",
        "thrustArea": "People & Culture",
        "uom_type": "numeric_min",
        "target": 3,
        "weightage": 20,
        "isShared": False,
    },
    {
        "goal_item_id": _id(),
        "title": "Zero Safety Incidents",
        "description": "Maintain zero workplace safety incidents throughout the year.",
        "thrustArea": "Quality & Compliance",
        "uom_type": "zero",
        "target": 0,
        "weightage": 15,
        "isShared": False,
    },
    {
        "goal_item_id": _id(),
        "title": "Launch 2 New Client Accounts",
        "description": "Identify and onboard two new enterprise accounts.",
        "thrustArea": "Revenue Growth",
        "uom_type": "numeric_min",
        "target": 2,
        "weightage": 10,
        "isShared": False,
    },
]

# Add quarterly data to each goal
q1_actuals = [
    {"actual": 3800000, "status": "on_track", "progress_score": 76},
    {"actual": 6, "status": "on_track", "progress_score": 83},
    {"actual": 2, "status": "on_track", "progress_score": 67},
    {"actual": 0, "status": "completed", "progress_score": 100},
    {"actual": 1, "status": "on_track", "progress_score": 50},
]

for i, goal in enumerate(emp1_goals):
    goal["quarterlyData"] = {
        "Q1": q1_actuals[i],
    }

emp1_sheet = {
    "employee_id": emp1_uid,
    "employee_name": "Ananya Iyer",
    "cycle_id": CYCLE_ID,
    "goals": emp1_goals,
    "total_weightage": 100,
    "sheet_status": "locked",
    "submitted_at": NOW - timedelta(days=10),
    "approved_at": NOW - timedelta(days=7),
    "approved_by": manager_uid,
    "manager_id": manager_uid,
    "createdAt": NOW - timedelta(days=14),
}

db.collection("goals").document(emp1_goal_id).set(emp1_sheet, merge=True)
print(f"  ✓ emp1 goal sheet: {emp1_goal_id} (locked, 5 goals)")

# ── 5. emp1 Q1 Check-in ─────────────────────────────────────────────────────

print("\n═══ 5. Seeding emp1 Q1 Check-in ═══")

emp1_checkin_id = f"checkin_{emp1_uid[:12]}_Q1"
checkin_actuals = []
for i, goal in enumerate(emp1_goals):
    checkin_actuals.append({
        "goal_item_id": goal["goal_item_id"],
        "actual_achievement": q1_actuals[i]["actual"],
        "actual": q1_actuals[i]["actual"],
        "status": q1_actuals[i]["status"],
        "progress_score": q1_actuals[i]["progress_score"],
    })

emp1_checkin = {
    "goal_id": emp1_goal_id,
    "employee_id": emp1_uid,
    "quarter": "Q1",
    "actuals": checkin_actuals,
    "overall_score": 75.2,
    "manager_comment": "Good progress on compliance. Push harder on revenue in Q2.",
    "ai_summary": (
        "Ananya demonstrated strong compliance performance with zero safety incidents, "
        "achieving a perfect score on her Quality & Compliance goal. Her revenue performance "
        "at ₹38L represents solid progress toward the ₹50L target, though accelerating "
        "client acquisition in Q2 will be critical. Training completion is on track at 67%, "
        "and the first new client account has been successfully onboarded. For Q2, "
        "prioritising the second enterprise account and completing the remaining training "
        "module will strengthen her overall trajectory."
    ),
    "ai_summary_generated_at": NOW - timedelta(days=2),
    "submitted_at": NOW - timedelta(days=5),
    "reviewed_at": NOW - timedelta(days=3),
    "createdAt": NOW - timedelta(days=5),
}

db.collection("checkins").document(emp1_checkin_id).set(emp1_checkin, merge=True)
print(f"  ✓ Q1 check-in: {emp1_checkin_id}")

# ── 6. emp2 Goal Sheet (submitted, pending approval) ────────────────────────

print("\n═══ 6. Seeding emp2 Goal Sheet (submitted) ═══")

emp2_goal_id = f"goal_{emp2_uid[:12]}"
emp2_goals = [
    {
        "goal_item_id": _id(),
        "title": "Generate 50 Qualified Leads per Quarter",
        "description": "Build pipeline through outbound campaigns and networking.",
        "thrustArea": "Revenue Growth",
        "uom_type": "numeric_min",
        "target": 50,
        "weightage": 40,
        "isShared": False,
        "quarterlyData": {},
    },
    {
        "goal_item_id": _id(),
        "title": "Achieve 80% Proposal Win Rate",
        "description": "Improve proposal quality and client follow-up cadence.",
        "thrustArea": "Customer Experience",
        "uom_type": "percent_min",
        "target": 80,
        "weightage": 35,
        "isShared": False,
        "quarterlyData": {},
    },
    {
        "goal_item_id": _id(),
        "title": "Conduct 4 Industry Webinars",
        "description": "Position the company as a thought leader in target verticals.",
        "thrustArea": "People & Culture",
        "uom_type": "numeric_min",
        "target": 4,
        "weightage": 25,
        "isShared": False,
        "quarterlyData": {},
    },
]

emp2_sheet = {
    "employee_id": emp2_uid,
    "employee_name": "Karthik Nair",
    "cycle_id": CYCLE_ID,
    "goals": emp2_goals,
    "total_weightage": 100,
    "sheet_status": "submitted",
    "submitted_at": NOW - timedelta(days=2),
    "manager_id": manager_uid,
    "createdAt": NOW - timedelta(days=5),
}

db.collection("goals").document(emp2_goal_id).set(emp2_sheet, merge=True)
print(f"  ✓ emp2 goal sheet: {emp2_goal_id} (submitted, 3 goals)")

# ── 7. emp3 Goal Sheet (draft, 2 goals, 50% weightage) ──────────────────────

print("\n═══ 7. Seeding emp3 Goal Sheet (draft) ═══")

emp3_goal_id = f"goal_{emp3_uid[:12]}"
emp3_goals = [
    {
        "goal_item_id": _id(),
        "title": "Retain 95% of Key Accounts",
        "description": "Proactive engagement to maintain and grow key account relationships.",
        "thrustArea": "Customer Experience",
        "uom_type": "percent_min",
        "target": 95,
        "weightage": 30,
        "isShared": False,
        "quarterlyData": {},
    },
    {
        "goal_item_id": _id(),
        "title": "Increase Account Upsell Revenue by 20%",
        "description": "Identify and convert upsell opportunities in existing portfolio.",
        "thrustArea": "Revenue Growth",
        "uom_type": "percent_min",
        "target": 20,
        "weightage": 20,
        "isShared": False,
        "quarterlyData": {},
    },
]

emp3_sheet = {
    "employee_id": emp3_uid,
    "employee_name": "Deepa Raj",
    "cycle_id": CYCLE_ID,
    "goals": emp3_goals,
    "total_weightage": 50,
    "sheet_status": "draft",
    "manager_id": manager_uid,
    "createdAt": NOW - timedelta(days=3),
}

db.collection("goals").document(emp3_goal_id).set(emp3_sheet, merge=True)
print(f"  ✓ emp3 goal sheet: {emp3_goal_id} (draft, 2 goals, 50%)")

# ── 8. Shared Goal ──────────────────────────────────────────────────────────

print("\n═══ 8. Seeding Shared Goal ═══")

shared_goal_id = _id()
shared_goal = {
    "title": "Team Q1 Revenue Target",
    "description": "Collective team revenue target for Q1.",
    "thrustArea": "Revenue Growth",
    "uomType": "numeric_min",
    "target": 12000000,
    "ownerEmployeeId": manager_uid,
    "assignedTo": [emp1_uid, emp2_uid, emp3_uid],
    "createdBy": manager_uid,
    "createdAt": NOW - timedelta(days=6),
}

db.collection("shared_goals").document(shared_goal_id).set(shared_goal, merge=True)
print(f"  ✓ Shared goal: {shared_goal_id}")

# ── 9. Audit Log ─────────────────────────────────────────────────────────────

print("\n═══ 9. Seeding Audit Log ═══")

audit_entries = [
    {
        "action": "goal_unlocked",
        "actor_id": admin_uid,
        "actor_name": "Priya Sharma",
        "actor_role": "admin",
        "employee_id": emp1_uid,
        "employee_name": "Ananya Iyer",
        "reason": "Employee requested correction to goal description",
        "timestamp": NOW - timedelta(days=3),
        "createdAt": NOW - timedelta(days=3),
    },
    {
        "action": "goal_approved",
        "actor_id": manager_uid,
        "actor_name": "Rahul Mehta",
        "actor_role": "manager",
        "employee_id": emp1_uid,
        "employee_name": "Ananya Iyer",
        "reason": "Goals reviewed and approved",
        "timestamp": NOW - timedelta(days=7),
        "createdAt": NOW - timedelta(days=7),
    },
]

for entry in audit_entries:
    db.collection("audit_logs").document(_id()).set(entry)
    print(f"  ✓ {entry['action']} by {entry['actor_name']}")

# ── 10. Notifications ────────────────────────────────────────────────────────

print("\n═══ 10. Seeding Notifications ═══")

notifications = [
    {
        "recipientId": emp1_uid,
        "title": "Goal Sheet Approved",
        "body": "Your goal sheet has been approved by Rahul Mehta.",
        "type": "approval",
        "isRead": True,
        "createdAt": NOW - timedelta(days=7),
    },
    {
        "recipientId": emp1_uid,
        "title": "Q1 Check-in Reviewed",
        "body": "Your Q1 check-in has been reviewed by Rahul Mehta.",
        "type": "checkin",
        "isRead": True,
        "createdAt": NOW - timedelta(days=3),
    },
    {
        "recipientId": emp1_uid,
        "title": "Shared Goal Assigned",
        "body": "A shared goal 'Team Q1 Revenue Target' has been added to your sheet.",
        "type": "shared",
        "isRead": False,
        "createdAt": NOW - timedelta(hours=2),
    },
    # Manager notifications
    {
        "recipientId": manager_uid,
        "title": "Goal Sheet Submitted",
        "body": "Karthik Nair has submitted their goal sheet for your review.",
        "type": "approval",
        "isRead": False,
        "createdAt": NOW - timedelta(days=2),
    },
    {
        "recipientId": manager_uid,
        "title": "Q1 Actuals Submitted",
        "body": "Ananya Iyer has submitted Q1 actuals for review.",
        "type": "checkin",
        "isRead": True,
        "createdAt": NOW - timedelta(days=5),
    },
]

for notif in notifications:
    db.collection("notifications").document(_id()).set(notif)
    print(f"  ✓ → {notif['recipientId'][:8]}... : {notif['title']}")

# ── Done ─────────────────────────────────────────────────────────────────────

print("\n" + "═" * 60)
print("✅ Demo data seeded successfully. All accounts ready.")
print("═" * 60)
print("\n  Accounts:")
print("  ─────────")
print("  admin@demo.com    / Demo@1234  (Admin)")
print("  manager@demo.com  / Demo@1234  (Manager)")
print("  emp1@demo.com     / Demo@1234  (Employee — locked goals + Q1 data)")
print("  emp2@demo.com     / Demo@1234  (Employee — submitted, pending approval)")
print("  emp3@demo.com     / Demo@1234  (Employee — draft)")
print()
