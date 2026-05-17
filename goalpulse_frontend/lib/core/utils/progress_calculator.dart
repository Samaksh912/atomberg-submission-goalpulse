/// Client-side progress score calculator — mirrors backend formulas exactly.
///
/// Returns a score between 0.0 and 100.0.
double calculateProgressScore(String uomType, dynamic target, dynamic actual) {
  if (actual == null) return 0.0;

  try {
    switch (uomType) {
      case 'numeric_max':
      case 'percent_max':
        // Higher actual is better.
        final t = _toDouble(target);
        final a = _toDouble(actual);
        if (t == 0) return a >= 0 ? 100.0 : 0.0;
        if (a == 0) return 0.0;
        return _clamp((a / t) * 100.0);

      case 'numeric_min':
      case 'percent_min':
        // Lower actual is better.
        final t = _toDouble(target);
        final a = _toDouble(actual);
        if (a == 0) return t == 0 ? 100.0 : 0.0;
        if (t == 0) return 0.0;
        return _clamp((t / a) * 100.0);

      case 'timeline':
        return _timelineScore(target.toString(), actual.toString());

      case 'zero':
        return _toDouble(actual) == 0 ? 100.0 : 0.0;

      default:
        return 0.0;
    }
  } catch (_) {
    return 0.0;
  }
}

double _timelineScore(String deadlineStr, String actualStr) {
  try {
    final deadline = DateTime.parse(deadlineStr.trim().substring(0, 10));
    final actual = DateTime.parse(actualStr.trim().substring(0, 10));

    if (!actual.isAfter(deadline)) return 100.0;

    // Partial credit.
    const totalDays = 90.0;
    final daysOverdue = actual.difference(deadline).inDays;
    return _clamp(((totalDays - daysOverdue) / totalDays) * 100.0);
  } catch (_) {
    return 0.0;
  }
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

double _clamp(double score) => score.clamp(0.0, 100.0);
