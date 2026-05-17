"""Analytics & reporting endpoints."""

from fastapi import APIRouter

router = APIRouter(prefix="/v1/analytics", tags=["analytics"])


@router.get("/")
async def analytics_root():
    """Stub – will host dashboard aggregation endpoints."""
    return {"message": "analytics router ready"}
