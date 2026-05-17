"""AI-powered features using Google Gemini API."""

from __future__ import annotations

import json
from typing import Any

import google.generativeai as genai

from config import settings
from app.services.firebase_service import db

# ── Setup ─────────────────────────────────────────────────────────────────────

genai.configure(api_key=settings.gemini_api_key)
_model = genai.GenerativeModel("gemini-1.5-flash")

# ── Fallback seeds (used when Gemini is unavailable) ─────────────────────────

_FALLBACK_GOALS: dict[str, list[dict]] = {
    "Revenue Growth": [
        {
            "title": "Increase quarterly revenue by 15%",
            "description": "Drive revenue through new client acquisition and upselling to existing accounts.",
            "uom_type": "percent_max",
            "recommended_target": "15",
            "rationale": "Revenue growth is the primary metric for business health.",
        },
        {
            "title": "Close 10 new enterprise deals",
            "description": "Identify, qualify, and close deals with enterprise-tier clients.",
            "uom_type": "numeric_max",
            "recommended_target": "10",
            "rationale": "Enterprise accounts have higher lifetime value and strategic importance.",
        },
        {
            "title": "Achieve 90% renewal rate",
            "description": "Retain existing clients through proactive engagement and value delivery.",
            "uom_type": "percent_max",
            "recommended_target": "90",
            "rationale": "Retention is more cost-effective than acquisition.",
        },
    ],
    "Customer Experience": [
        {
            "title": "Achieve NPS score of 70+",
            "description": "Improve net promoter score through enhanced support and product quality.",
            "uom_type": "numeric_max",
            "recommended_target": "70",
            "rationale": "NPS directly correlates with customer loyalty and word-of-mouth growth.",
        },
        {
            "title": "Reduce average ticket resolution time to 4 hours",
            "description": "Streamline support processes to resolve customer issues faster.",
            "uom_type": "numeric_min",
            "recommended_target": "4",
            "rationale": "Faster resolution improves satisfaction and reduces churn.",
        },
        {
            "title": "Achieve 95% customer satisfaction score",
            "description": "Collect and act on customer feedback to maintain high satisfaction levels.",
            "uom_type": "percent_max",
            "recommended_target": "95",
            "rationale": "CSAT is the direct measure of customer experience quality.",
        },
    ],
}

_DEFAULT_FALLBACK_SUGGESTIONS = [
    {
        "title": "Achieve primary KPI target for this area",
        "description": "Define and consistently track the core metric for this thrust area.",
        "uom_type": "percent_max",
        "recommended_target": "100",
        "rationale": "Tracking primary KPIs ensures alignment with organisational goals.",
    },
    {
        "title": "Reduce process inefficiencies by 20%",
        "description": "Identify bottlenecks and implement improvements to reduce waste.",
        "uom_type": "percent_min",
        "recommended_target": "20",
        "rationale": "Efficiency improvements compound over time and reduce operating costs.",
    },
    {
        "title": "Complete all milestones on schedule",
        "description": "Deliver all planned milestones within agreed timelines.",
        "uom_type": "timeline",
        "recommended_target": "2025-12-31",
        "rationale": "Timely delivery demonstrates execution capability and reliability.",
    },
]


# ── Core helper ───────────────────────────────────────────────────────────────

async def call_gemini(prompt: str, fallback: Any) -> Any:
    """Call Gemini and parse JSON response. Returns fallback on any error."""
    try:
        response = _model.generate_content(prompt)
        text = response.text.strip()
        # Strip markdown code fences.
        text = text.replace("```json", "").replace("```", "").strip()
        return json.loads(text)
    except Exception as e:
        print(f"[Gemini] error: {e}")
        return fallback


# ── Function 1: Goal Suggestions ─────────────────────────────────────────────

async def suggest_goals(
    role: str,
    department: str,
    thrust_area: str,
    existing_goal_titles: list[str],
) -> dict[str, Any]:
    """Generate 3 SMART goal suggestions for the given thrust area."""
    existing_str = (
        ", ".join(existing_goal_titles) if existing_goal_titles else "None"
    )
    prompt = f"""You are an expert performance management consultant helping employees set SMART goals.
Employee role: {role}
Department: {department}
Thrust Area: {thrust_area}
Existing goals (avoid duplicates): {existing_str}

Generate exactly 3 diverse, specific, measurable goal suggestions for this Thrust Area.
Return ONLY valid JSON (no markdown, no explanation):
{{
  "suggestions": [
    {{
      "title": "Goal title, max 60 characters",
      "description": "Clear description of what success looks like, max 150 characters",
      "uom_type": "numeric_min OR numeric_max OR percent_min OR percent_max OR timeline OR zero",
      "recommended_target": "specific number or date",
      "rationale": "One sentence why this goal matters for this role/thrust area"
    }}
  ]
}}"""

    fallback_list = _FALLBACK_GOALS.get(thrust_area, _DEFAULT_FALLBACK_SUGGESTIONS)
    fallback = {"suggestions": fallback_list[:3]}
    return await call_gemini(prompt, fallback)


# ── Function 2: Quarterly Summary ────────────────────────────────────────────

async def generate_quarterly_summary(
    employee_name: str,
    role: str,
    quarter: str,
    goals_with_actuals: list[dict],
    manager_comment: str | None,
) -> str:
    """Generate a 4–5 sentence professional performance summary."""
    goals_text = "\n".join(
        f"- {g.get('title', 'Goal')}: target={g.get('target')}, "
        f"actual={g.get('actual', 'not submitted')}, "
        f"score={g.get('progress_score', 0):.0f}%"
        for g in goals_with_actuals
    )
    prompt = f"""You are a professional HR performance analyst writing a quarterly performance summary.
Write exactly 4-5 sentences. Be specific, constructive, and professional.
Do not use generic phrases like "continued to demonstrate" or "showed dedication".

Employee: {employee_name}, Role: {role}, Quarter: {quarter}

Goals performance:
{goals_text}

Manager's comment: {manager_comment or 'Not provided'}

Write only the summary paragraph. No JSON, no headers, no bullet points.
Start with the employee's strongest achievement. End with a forward-looking recommendation."""

    result = await call_gemini(
        prompt,
        f"Performance summary for {quarter}: {employee_name} completed the quarterly goals. "
        "Please review individual goal scores above for detailed performance data.",
    )
    # generate_quarterly_summary returns a plain string (not JSON).
    if isinstance(result, str):
        return result
    # If Gemini returned JSON for some reason, extract text.
    if isinstance(result, dict):
        return result.get("summary", str(result))
    return str(result)


async def _generate_summary_raw(prompt: str, fallback: str) -> str:
    """Variant that calls Gemini expecting plain text (not JSON)."""
    try:
        response = _model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        print(f"[Gemini] summary error: {e}")
        return fallback


async def generate_quarterly_summary_text(
    employee_name: str,
    role: str,
    quarter: str,
    goals_with_actuals: list[dict],
    manager_comment: str | None,
) -> str:
    """Generate a plain-text 4–5 sentence summary (no JSON parsing)."""
    goals_text = "\n".join(
        f"- {g.get('title', 'Goal')}: target={g.get('target')}, "
        f"actual={g.get('actual', 'not submitted')}, "
        f"score={g.get('progress_score', 0):.0f}%"
        for g in goals_with_actuals
    )
    prompt = f"""You are a professional HR performance analyst writing a quarterly performance summary.
Write exactly 4-5 sentences. Be specific, constructive, and professional.
Do not use generic phrases like "continued to demonstrate" or "showed dedication".

Employee: {employee_name}, Role: {role}, Quarter: {quarter}

Goals performance:
{goals_text}

Manager's comment: {manager_comment or 'Not provided'}

Write only the summary paragraph. No JSON, no headers, no bullet points.
Start with the employee's strongest achievement. End with a forward-looking recommendation."""

    fallback = (
        f"Performance summary for {quarter}: {employee_name} completed the quarterly goals. "
        "Please review individual goal scores above for detailed performance data."
    )
    return await _generate_summary_raw(prompt, fallback)


# ── Function 3: Risk Prediction ───────────────────────────────────────────────

async def predict_goal_risks(
    goals_with_actuals: list[dict],
    quarter: str,
) -> dict[str, Any]:
    """Pre-compute risk levels in Python; call Gemini only for high/medium."""
    risk_items = []
    for goal in goals_with_actuals:
        uom = goal.get("uom_type", "")
        q1_score = float(goal.get("q1_score", 0))
        title = goal.get("title", "Unnamed Goal")
        goal_item_id = goal.get("goal_item_id", "")

        if uom in ("numeric_min", "percent_min"):
            # Lower is better — if trajectory < 90% of target, flag it.
            risk_level = "low" if q1_score >= 90 else "medium" if q1_score >= 60 else "high"
        elif uom == "zero":
            risk_level = "high" if q1_score < 100 else "low"
        elif uom in ("numeric_max", "percent_max"):
            risk_level = "low" if q1_score >= 80 else "medium" if q1_score >= 50 else "high"
        else:
            risk_level = "low"

        risk_items.append(
            {
                "goal_item_id": goal_item_id,
                "goal_title": title,
                "risk_level": risk_level,
                "recommendation": None,
            }
        )

    # Only call Gemini for at-risk goals.
    high_medium = [r for r in risk_items if r["risk_level"] in ("high", "medium")]
    if high_medium:
        prompt = f"""For each at-risk goal below, provide a one-sentence actionable recommendation.
Return ONLY valid JSON:
{{ "recommendations": [ {{ "goal_title": "...", "recommendation": "..." }} ] }}

At-risk goals: {json.dumps([{{"goal_title": r["goal_title"], "risk_level": r["risk_level"]}} for r in high_medium])}"""

        result = await call_gemini(prompt, {"recommendations": []})
        recs = {r["goal_title"]: r["recommendation"] for r in result.get("recommendations", [])}
        for item in risk_items:
            if item["goal_title"] in recs:
                item["recommendation"] = recs[item["goal_title"]]

    return {"risks": risk_items}


# ── Function 4: KPI Recommendations ─────────────────────────────────────────

async def recommend_kpi(
    thrust_area: str,
    goal_title: str,
    role: str,
) -> dict[str, Any]:
    """Recommend UoM type and target for a goal."""
    prompt = f"""An employee with role "{role}" is creating a goal titled "{goal_title}" 
under the Thrust Area "{thrust_area}".

Recommend the most appropriate measurement approach.
Return ONLY valid JSON:
{{
  "uom_type": "numeric_min OR numeric_max OR percent_min OR percent_max OR timeline OR zero",
  "target_suggestion": "a specific suggested target value as a string",
  "rationale": "One sentence explaining why this measurement approach fits"
}}"""

    fallback = {
        "uom_type": "numeric_max",
        "target_suggestion": "100",
        "rationale": "Numeric target provides clear, measurable success criteria.",
    }
    return await call_gemini(prompt, fallback)
