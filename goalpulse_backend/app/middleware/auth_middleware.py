"""FastAPI dependency functions for Firebase token verification and role enforcement."""

from fastapi import Depends, Header, HTTPException, status

from app.services.firebase_service import auth, db


async def get_current_user(
    authorization: str = Header(..., description="Bearer <Firebase ID token>"),
) -> dict:
    """Verify the Firebase ID token and return the GoalPulse user profile.

    Raises:
        HTTPException 401: token missing, malformed, or expired.
        HTTPException 403: authenticated user has no document in Firestore.
    """
    # ── Extract token ─────────────────────────────────────────────────────
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header must be: Bearer <token>",
        )

    # ── Verify with Firebase ──────────────────────────────────────────────
    try:
        decoded = auth.verify_id_token(token)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired token: {exc}",
        )

    uid = decoded["uid"]

    # ── Fetch Firestore profile ───────────────────────────────────────────
    doc = db.collection("users").document(uid).get()
    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User profile not found. Contact your administrator.",
        )

    data = doc.to_dict()
    return {
        "uid": uid,
        "email": decoded.get("email", data.get("email", "")),
        "role": data.get("role", "employee"),
        "display_name": data.get("display_name", data.get("displayName", decoded.get("name", ""))),
        "manager_id": data.get("manager_id", data.get("managerId")),
        "department": data.get("department", ""),
    }


# ── Role guard dependencies ───────────────────────────────────────────────


async def require_employee(
    user: dict = Depends(get_current_user),
) -> dict:
    """Allow only employees (and admins acting as employees)."""
    if user["role"] not in ("employee",):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Employee access required.",
        )
    return user


async def require_manager(
    user: dict = Depends(get_current_user),
) -> dict:
    """Allow managers and admins."""
    if user["role"] not in ("manager", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Manager or Admin access required.",
        )
    return user


async def require_admin(
    user: dict = Depends(get_current_user),
) -> dict:
    """Allow admins only."""
    if user["role"] != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required.",
        )
    return user
