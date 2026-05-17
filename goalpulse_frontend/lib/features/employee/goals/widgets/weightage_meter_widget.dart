import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../goals_provider.dart';

/// Full-width progress bar showing total weightage with per-goal chips.
class WeightageMeterWidget extends ConsumerWidget {
  const WeightageMeterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final validation = ref.watch(weightageValidationProvider);
    final goals = ref.watch(localDraftGoalsProvider);
    final isValid = validation.isValid;
    final barColor = isValid ? AppColors.kSuccess : AppColors.kDanger;
    final fillFraction = (validation.total / 100.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Weightage',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.kTextPrimary)),
              Text(
                '${validation.total.toStringAsFixed(0)}% / 100%',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Progress bar ─────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: AppColors.kNeutral100,
                  ),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    widthFactor: fillFraction,
                    child: Container(
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Per-goal chips ───────────────────────────────────────
          if (goals.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(goals.length, (i) {
                final g = goals[i];
                final label = g.title.isNotEmpty
                    ? g.title
                    : 'Goal ${i + 1}';
                final isBelowMin = g.weightage < 10;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isBelowMin
                        ? AppColors.kDanger.withValues(alpha: 0.1)
                        : AppColors.kBrandPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isBelowMin
                          ? AppColors.kDanger.withValues(alpha: 0.3)
                          : AppColors.kBrandPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '${_truncate(label, 12)}: ${g.weightage.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isBelowMin
                          ? AppColors.kDanger
                          : AppColors.kBrandPrimary,
                    ),
                  ),
                );
              }),
            ),
          const SizedBox(height: 8),

          // ── Validation messages ──────────────────────────────────
          if (isValid)
            Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 15, color: AppColors.kSuccess),
                const SizedBox(width: 6),
                Text('Weightage valid',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.kSuccess)),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 15, color: AppColors.kDanger),
                const SizedBox(width: 6),
                Text('Total must equal 100%',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.kDanger)),
              ],
            ),
          if (validation.hasUnderMinimum) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 15, color: AppColors.kDanger),
                const SizedBox(width: 6),
                Text('One or more goals are below minimum 10%',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.kDanger)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}

/// A FractionallySizedBox that animates its [widthFactor].
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  const AnimatedFractionallySizedBox({
    super.key,
    required super.duration,
    super.curve,
    required this.widthFactor,
    required this.child,
  });

  final double widthFactor;
  final Widget child;

  @override
  AnimatedWidgetBaseState<AnimatedFractionallySizedBox> createState() =>
      _AnimatedFractionallySizedBoxState();
}

class _AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor = visitor(
      _widthFactor,
      widget.widthFactor,
      (value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: _widthFactor!.evaluate(animation),
      alignment: Alignment.centerLeft,
      child: widget.child,
    );
  }
}
