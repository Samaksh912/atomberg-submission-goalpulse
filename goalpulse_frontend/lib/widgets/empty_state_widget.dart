import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// Centered empty-state placeholder with icon, title, subtitle, and
/// optional call-to-action button.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.ctaLabel,
    this.onCta,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Icon ──────────────────────────────────────────────────────────
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.kBrandPrimary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.kBrandPrimary),
          ),
          const SizedBox(height: 20),

          // ── Title ─────────────────────────────────────────────────────────
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.kTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // ── Subtitle ──────────────────────────────────────────────────────
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.kTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // ── CTA button ────────────────────────────────────────────────────
          if (ctaLabel != null && onCta != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onCta, child: Text(ctaLabel!)),
          ],
        ],
      ),
    );
  }
}
