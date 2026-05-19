"""Firebase Admin SDK initialisation and shared client objects.

Import `db` for Firestore and `auth` for Firebase Auth operations anywhere in
the backend. The SDK is initialised exactly once; subsequent imports reuse the
existing app.
"""

import base64
import json

import firebase_admin
from firebase_admin import credentials, firestore, auth as firebase_auth

from config import settings

# ── Initialise Firebase Admin ─────────────────────────────────────────────


def _init_firebase() -> None:
    """Initialise the default Firebase app from service-account credentials."""
    if firebase_admin._apps:
        return

    raw_val = settings.firebase_service_account_json
    if raw_val:
        import os
        if raw_val.endswith('.json') and os.path.exists(raw_val):
            # Hackathon shortcut: just use the file directly!
            cred = credentials.Certificate(raw_val)
        else:
            try:
                # Try as raw JSON first.
                service_account_info = json.loads(raw_val)
            except json.JSONDecodeError:
                # Fallback to base64.
                service_account_info = json.loads(base64.b64decode(raw_val))
            cred = credentials.Certificate(service_account_info)
    else:
        cred = credentials.ApplicationDefault()

    firebase_admin.initialize_app(cred, {
        "projectId": settings.firebase_project_id or None,
    })


_init_firebase()

# ── Public singletons ─────────────────────────────────────────────────────

#: Firestore client — use for all database operations.
db: firestore.Client = firestore.client()

#: Firebase Auth module — use for token verification and user management.
auth = firebase_auth
