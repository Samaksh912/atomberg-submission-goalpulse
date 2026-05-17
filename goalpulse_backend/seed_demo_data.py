#!/usr/bin/env python3
"""seed_demo_data.py — Seed Firebase Auth + Firestore with GoalPulse demo accounts.

Usage (from goalpulse_backend/):
    source venv/bin/activate
    python seed_demo_data.py

Requires a populated .env file (or env vars):
    FIREBASE_PROJECT_ID=...
    FIREBASE_SERVICE_ACCOUNT_JSON=<base64-encoded JSON>
"""

import base64
import json
import os
import sys
from datetime import datetime, timezone

# Bootstrap config before importing app modules.
from dotenv import load_dotenv
load_dotenv()

import firebase_admin
from firebase_admin import auth, credentials, firestore

# ── Firebase init ─────────────────────────────────────────────────────────

_sa_str = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "")
_project = os.getenv("FIREBASE_PROJECT_ID", "")

if _sa_str:
    try:
        # Try as raw JSON first.
        _sa_json = json.loads(_sa_str)
    except json.JSONDecodeError:
        # Fallback to base64.
        _sa_json = json.loads(base64.b64decode(_sa_str))
    _cred = credentials.Certificate(_sa_json)
else:
    print("⚠  FIREBASE_SERVICE_ACCOUNT_JSON not set — using Application Default Credentials.")
    _cred = credentials.ApplicationDefault()

if not firebase_admin._apps:
    firebase_admin.initialize_app(_cred, {"projectId": _project or None})

db = firestore.client()

# ── Demo users ─────────────────────────────────────────────────────────────

DEMO_USERS = [
    {
        "email": "admin@demo.com",
        "password": "Demo@1234",
        "display_name": "Demo Admin",
        "role": "admin",
        "department": "IT",
        "designation": "System Administrator",
    },
    {
        "email": "manager@demo.com",
        "password": "Demo@1234",
        "display_name": "Demo Manager",
        "role": "manager",
        "department": "Engineering",
        "designation": "Engineering Manager",
    },
    {
        "email": "emp1@demo.com",
        "password": "Demo@1234",
        "display_name": "Demo Employee",
        "role": "employee",
        "department": "Engineering",
        "designation": "Software Engineer",
    },
]

# ── Seeding logic ─────────────────────────────────────────────────────────


def seed_user(user_data: dict) -> None:
    email = user_data["email"]
    role = user_data["role"]

    # Create or fetch Firebase Auth user.
    try:
        fb_user = auth.get_user_by_email(email)
        print(f"  ⏭  {email} — Auth user already exists (uid={fb_user.uid})")
    except auth.UserNotFoundError:
        fb_user = auth.create_user(
            email=email,
            password=user_data["password"],
            display_name=user_data["display_name"],
            email_verified=True,
        )
        print(f"  ✅  {email} — Auth user created (uid={fb_user.uid})")

    uid = fb_user.uid

    # Set custom JWT claims.
    auth.set_custom_user_claims(uid, {"role": role})
    print(f"       Claims set → role={role}")

    # Upsert Firestore document.
    now = datetime.now(timezone.utc)
    ref = db.collection("users").document(uid)
    doc = ref.get()

    fs_data = {
        "id": uid,
        "email": email,
        "display_name": user_data["display_name"],
        "role": role,
        "manager_id": None,
        "department": user_data.get("department", ""),
        "designation": user_data.get("designation", ""),
        "is_active": True,
        "azure_ad_object_id": None,
        "updated_at": now,
    }

    if doc.exists:
        ref.update(fs_data)
        print(f"       Firestore updated")
    else:
        ref.set({**fs_data, "created_at": now})
        print(f"       Firestore document created")


def main() -> None:
    print("\n🌱  GoalPulse demo data seeder\n" + "=" * 40)
    errors = []
    for user in DEMO_USERS:
        print(f"\n→ {user['email']} ({user['role']})")
        try:
            seed_user(user)
        except Exception as exc:
            print(f"  ❌ Error: {exc}")
            errors.append(user["email"])

    print("\n" + "=" * 40)
    if errors:
        print(f"⚠  Completed with errors for: {', '.join(errors)}")
        sys.exit(1)
    else:
        print("✅  All demo users seeded successfully!")


if __name__ == "__main__":
    main()
