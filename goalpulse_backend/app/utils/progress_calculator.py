"""Progress score computation for all UoM types.

Formulas:
  numeric_min / percent_min (lower is better):  score = (target / actual) * 100
  numeric_max / percent_max (higher is better): score = (actual / target) * 100
  timeline: 100 if on/before deadline, partial credit otherwise
  zero:     100 if actual == 0, else 0

All scores clamped to [0.0, 100.0].
"""

from __future__ import annotations

from datetime import datetime


def calculate_progress_score(
    uom_type: str,
    target,
    actual,
) -> float:
    """Return a progress score between 0.0 and 100.0."""
    if actual is None:
        return 0.0

    try:
        if uom_type in ("numeric_max", "percent_max"):
            # Higher actual is better.
            t = float(target)
            a = float(actual)
            if t == 0:
                return 100.0 if a >= 0 else 0.0
            if a == 0:
                return 0.0
            score = (a / t) * 100.0
            return _clamp(score)

        if uom_type in ("numeric_min", "percent_min"):
            # Lower actual is better.
            t = float(target)
            a = float(actual)
            if a == 0:
                return 100.0 if t == 0 else 0.0
            if t == 0:
                return 0.0
            score = (t / a) * 100.0
            return _clamp(score)

        if uom_type == "timeline":
            return _timeline_score(str(target), str(actual))

        if uom_type == "zero":
            a = float(actual)
            return 100.0 if a == 0 else 0.0

    except (ValueError, TypeError, ZeroDivisionError):
        return 0.0

    return 0.0


def _timeline_score(deadline_str: str, actual_str: str) -> float:
    """Score a timeline goal with partial credit for late delivery."""
    try:
        deadline = _parse_date(deadline_str)
        actual = _parse_date(actual_str)
    except (ValueError, TypeError):
        return 0.0

    if actual <= deadline:
        return 100.0

    # Partial credit: (total_days - days_overdue) / total_days * 100
    # Use 90 days as the reference total window if we don't have a start date.
    total_days = 90.0
    days_overdue = (actual - deadline).days
    score = ((total_days - days_overdue) / total_days) * 100.0
    return _clamp(score)


def _parse_date(s: str) -> datetime:
    """Parse ISO date string YYYY-MM-DD."""
    return datetime.strptime(s.strip()[:10], "%Y-%m-%d")


def _clamp(score: float) -> float:
    """Clamp score to [0, 100]."""
    return max(0.0, min(score, 100.0))
