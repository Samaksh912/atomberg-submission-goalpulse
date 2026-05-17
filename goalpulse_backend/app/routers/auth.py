"""Auth router — token verification and dev-only claim seeding."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.middleware.auth_middleware import get_current_user
from app.services.firebase_service import auth, db
from config import settings

router = APIRouter(prefix="/v1/auth", tags=["auth"])


# ── POST /auth/verify ─────────────────────────────────────────────────────


@router.post("/verify")
async def verify_token(user: dict = Depends(get_current_user)):
    """Verify the caller's Firebase ID token.

    If the user document does not yet exist in Firestore, it is auto-created
    with role='employee'. Returns the normalised user profile.
    """
    uid = user["uid"]
    ref = db.collection("users").document(uid)
    doc = ref.get()

    if not doc.exists:
        # First-time login — provision with default role.
        now = datetime.now(timezone.utc)
        profile = {
            "id": uid,
            "email": user["email"],
            "display_name": user["display_name"],
            "role": "employee",
            "manager_id": None,
            "department": "",
            "designation": "",
            "is_active": True,
            "azure_ad_object_id": None,
            "created_at": now,
            "updated_at": now,
        }
        ref.set(profile)
    else:
        profile = doc.to_dict()

    return {
        "userId": uid,
        "email": profile.get("email", ""),
        "displayName": profile.get("display_name", ""),
        "role": profile.get("role", "employee"),
        "managerId": profile.get("manager_id"),
        "department": profile.get("department", ""),
        "isActive": profile.get("is_active", True),
    }


# ── POST /auth/set-demo-claims (DEV ONLY) ─────────────────────────────────


class SetClaimsRequest(BaseModel):
    email: str
    role: str


@router.post("/set-demo-claims")
async def set_demo_claims(body: SetClaimsRequest):
    """Set custom claims for a demo user.

    **Development environment only** — returns 404 in production.
    """
    if settings.environment != "development":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    if body.role not in ("employee", "manager", "admin"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="role must be one of: employee, manager, admin",
        )

    try:
        firebase_user = auth.get_user_by_email(body.email)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Firebase user not found: {body.email}",
        )

    uid = firebase_user.uid

    # Set custom JWT claims.
    auth.set_custom_user_claims(uid, {"role": body.role})

    # Upsert Firestore document.
    now = datetime.now(timezone.utc)
    ref = db.collection("users").document(uid)
    doc = ref.get()
    if doc.exists:
        ref.update({"role": body.role, "updated_at": now})
    else:
        ref.set({
            "id": uid,
            "email": body.email,
            "display_name": firebase_user.display_name or body.email.split("@")[0],
            "role": body.role,
            "manager_id": None,
            "department": "",
            "designation": "",
            "is_active": True,
            "azure_ad_object_id": None,
            "created_at": now,
            "updated_at": now,
        })

    return {"success": True, "uid": uid, "role": body.role}
