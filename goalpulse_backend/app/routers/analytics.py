"""Analytics endpoints — completion dashboards, QoQ trends, distributions."""

from __future__ import annotations

from typing import Optional
from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse

from app.middleware.auth_middleware import require_manager, require_admin, get_current_user
from app.services.analytics_service import analytics_service
from app.services.report_service import report_service

router = APIRouter(prefix="/v1/analytics", tags=["analytics"])


@router.get("/completion-dashboard")
async def completion_dashboard(
    cycle_id: str = Query("cycle_2025"),
    quarter: Optional[str] = Query(None),
    user: dict = Depends(require_manager),
):
    """Per-employee goal & check-in completion matrix."""
    return analytics_service.get_completion_dashboard(
        requester_id=user["uid"],
        role=user["role"],
        cycle_id=cycle_id,
        quarter=quarter,
    )


@router.get("/qoq-trends")
async def qoq_trends(
    cycle_id: str = Query("cycle_2025"),
    employee_id: Optional[str] = Query(None),
    department: Optional[str] = Query(None),
    user: dict = Depends(require_manager),
):
    """Average progress score and completion rate per quarter."""
    return analytics_service.get_qoq_trends(
        requester_id=user["uid"],
        role=user["role"],
        cycle_id=cycle_id,
        employee_id=employee_id,
        department=department,
    )


@router.get("/manager-effectiveness")
async def manager_effectiveness(
    cycle_id: str = Query("cycle_2025"),
    _user: dict = Depends(require_admin),
):
    """Per-manager check-in rates, avg scores, and approval turnaround."""
    return analytics_service.get_manager_effectiveness(cycle_id=cycle_id)


@router.get("/goal-distribution")
async def goal_distribution(
    cycle_id: str = Query("cycle_2025"),
    user: dict = Depends(require_manager),
):
    """Goal counts by thrust area, UoM type, and sheet status."""
    return analytics_service.get_goal_distribution(
        requester_id=user["uid"],
        role=user["role"],
        cycle_id=cycle_id,
    )


@router.get("/reports/achievement")
async def achievement_report(
    cycle_id: str = Query("cycle_2025"),
    quarter: Optional[str] = Query(None),
    format: str = Query("json", regex="^(json|csv|excel)$"),
    user: dict = Depends(require_manager),
):
    """Generate achievement report in json, csv, or excel format."""
    result = report_service.generate_achievement_report(
        requester_id=user["uid"],
        role=user["role"],
        cycle_id=cycle_id,
        quarter=quarter,
        format=format,
    )

    if format == "csv":
        filename = f"achievement_report_{cycle_id}.csv"
        return StreamingResponse(
            result,
            media_type="text/csv",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        )

    if format == "excel":
        filename = f"achievement_report_{cycle_id}.xlsx"
        return StreamingResponse(
            result,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        )

    return result
