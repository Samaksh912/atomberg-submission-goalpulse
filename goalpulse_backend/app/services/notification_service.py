"""Notification service — writes to Firestore and stubs email delivery."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional

from app.services.firebase_service import db


COLLECTION = "notifications"


def create_notification(
    recipient_id: str,
    notification_type: str,
    title: str,
    body: str,
    related_entity_type: str = "",
    related_entity_id: str = "",
) -> str:
    """Write a notification document to Firestore.

    Returns the auto-generated document ID.
    """
    now = datetime.now(timezone.utc)
    doc_data = {
        "recipient_id": recipient_id,
        "type": notification_type,
        "title": title,
        "body": body,
        "related_entity_type": related_entity_type,
        "related_entity_id": related_entity_id,
        "is_read": False,
        "created_at": now,
    }

    _, ref = db.collection(COLLECTION).add(doc_data)

    # Dev stub — print email.
    print(f"EMAIL: {title} → recipient={recipient_id}")

    return ref.id


def create_audit_log(
    action: str,
    actor_id: str,
    entity_type: str = "goal_sheet",
    entity_id: str = "",
    details: Optional[dict] = None,
) -> str:
    """Write an audit-log entry to Firestore."""
    now = datetime.now(timezone.utc)
    doc_data = {
        "action": action,
        "actor_id": actor_id,
        "entity_type": entity_type,
        "entity_id": entity_id,
        "details": details or {},
        "created_at": now,
    }
    _, ref = db.collection("audit_logs").add(doc_data)
    return ref.id
