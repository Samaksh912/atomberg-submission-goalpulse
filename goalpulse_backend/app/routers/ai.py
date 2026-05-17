"""AI‑powered features (Gemini integration)."""

from fastapi import APIRouter

router = APIRouter(prefix="/v1/ai", tags=["ai"])


@router.get("/")
async def ai_root():
    """Stub – will host AI suggestion & summarisation endpoints."""
    return {"message": "ai router ready"}
