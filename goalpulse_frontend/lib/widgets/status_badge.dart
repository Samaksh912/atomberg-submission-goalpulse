import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic status pill badge with colour-coded background and text.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(status.toLowerCase().replaceAll(' ', '_'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (style.icon != null) ...[
            Icon(style.icon, size: 13, color: style.fg),
            const SizedBox(width: 4),
          ],
          Text(
            style.label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: style.fg,
            ),
          ),
        ],
      ),
    );
  }

  static _BadgeStyle _resolveStyle(String key) => switch (key) {
        'approved' => const _BadgeStyle(
            bg: Color(0xFFD1FAE5),
            fg: Color(0xFF065F46),
            label: 'Approved'),
        'on_track' || 'ontrack' => const _BadgeStyle(
            bg: Color(0xFFD1FAE5),
            fg: Color(0xFF065F46),
            label: 'On Track'),
        'locked' => const _BadgeStyle(
            bg: Color(0xFFDBEAFE),
            fg: Color(0xFF1E40AF),
            label: 'Locked'),
        'completed' => const _BadgeStyle(
            bg: Color(0xFFDBEAFE),
            fg: Color(0xFF1E40AF),
            label: 'Completed'),
        'submitted' || 'pending' || 'actuals_submitted' => _BadgeStyle(
            bg: const Color(0xFFFEF3C7),
            fg: const Color(0xFF92400E),
            label: key == 'pending' ? 'Pending' : 'Submitted'),
        'draft' || 'not_started' || 'notstarted' => _BadgeStyle(
            bg: const Color(0xFFF3F4F6),
            fg: const Color(0xFF4B5563),
            label: key == 'draft' ? 'Draft' : 'Not Started'),
        'returned' => const _BadgeStyle(
            bg: Color(0xFFFEE2E2),
            fg: Color(0xFF991B1B),
            label: 'Returned'),
        'at_risk' || 'atrisk' => const _BadgeStyle(
            bg: Color(0xFFFEE2E2),
            fg: Color(0xFF991B1B),
            label: 'At Risk',
            icon: Icons.warning_amber_rounded),
        _ => _BadgeStyle(
            bg: const Color(0xFFF3F4F6),
            fg: const Color(0xFF4B5563),
            label: key),
      };
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.bg,
    required this.fg,
    required this.label,
    this.icon,
  });

  final Color bg;
  final Color fg;
  final String label;
  final IconData? icon;
}
