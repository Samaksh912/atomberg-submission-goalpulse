"""GoalPulse API — FastAPI application entry point."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings

# ── Router imports ────────────────────────────────────────────────────────
from app.routers import admin, ai, analytics, auth, checkins, goals, shared_goals

# ── Application ───────────────────────────────────────────────────────────
app = FastAPI(
    title="GoalPulse API",
    version="1.0.0",
    description="Enterprise Goal Setting & Tracking backend",
)

# ── CORS ──────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Health check ──────────────────────────────────────────────────────────


@app.get("/health", tags=["health"])
async def health_check():
    """Liveness probe — returns 200 when the service is up."""
    return {"status": "ok", "version": "1.0.0"}


# ── Register routers ─────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(goals.router)
app.include_router(checkins.router)
app.include_router(shared_goals.router)
app.include_router(analytics.router)
app.include_router(admin.router)
app.include_router(ai.router)
