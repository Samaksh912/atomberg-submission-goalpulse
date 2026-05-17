import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// A metric card that displays a single KPI value with optional trend indicator.
///
/// ```dart
/// KpiCard(
///   label: 'Total Goals',
///   value: '24',
///   icon: Icons.track_changes_outlined,
///   iconColor: AppColors.kBrandPrimary,
///   trend: '+12%',
///   trendUp: true,
/// )
/// ```
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.trend,
    this.trendUp,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? trend;
  final bool? trendUp;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kBorder.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Icon + trend row ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(38),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              if (trend != null) _buildTrendChip(),
            ],
          ),
          const SizedBox(height: 16),

          // ── Value ─────────────────────────────────────────────────────────
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.kTextPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),

          // ── Label ─────────────────────────────────────────────────────────
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.kTextSecondary,
            ),
          ),

          // ── Subtitle ──────────────────────────────────────────────────────
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.kTextSecondary.withAlpha(180),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendChip() {
    final isUp = trendUp ?? true;
    final color = isUp ? AppColors.kSuccess : AppColors.kDanger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            trend!,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
