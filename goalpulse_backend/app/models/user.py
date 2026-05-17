"""User domain model."""

from app.models.base import TimestampModel


class UserModel(TimestampModel):
    """Represents a GoalPulse user as stored in Firestore ``users/{uid}``."""

    id: str
    email: str
    display_name: str
    role: str  # 'employee' | 'manager' | 'admin'
    manager_id: str | None = None
    department: str = ""
    designation: str = ""
    is_active: bool = True
    azure_ad_object_id: str | None = None
