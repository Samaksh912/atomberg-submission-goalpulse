import 'package:flutter/material.dart';

/// GoalPulse brand & semantic color palette.
///
/// Every colour used in the application MUST reference a constant from this
/// file to guarantee visual consistency across the product.
class AppColors {
  AppColors._(); // prevent instantiation

  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color kBrandPrimary = Color(0xFF4F46E5);
  static const Color kBrandSecondary = Color(0xFF7C3AED);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color kSuccess = Color(0xFF10B981);
  static const Color kWarning = Color(0xFFF59E0B);
  static const Color kDanger = Color(0xFFEF4444);
  static const Color kInfo = Color(0xFF3B82F6);

  // ── Typography ─────────────────────────────────────────────────────────
  static const Color kTextPrimary = Color(0xFF111827);
  static const Color kTextSecondary = Color(0xFF4B5563);

  // ── Surfaces & Borders ─────────────────────────────────────────────────
  static const Color kBorder = Color(0xFFD1D5DB);
  static const Color kPageBackground = Color(0xFFF4F6F9);
  static const Color kCardBackground = Color(0xFFFFFFFF);
  static const Color kNeutral100 = Color(0xFFF3F4F6);
}
