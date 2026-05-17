import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../features/ai/ai_provider.dart';
import '../../../../features/manager/approvals/approvals_provider.dart';

/// Auto-fetching risk alerts card for the manager dashboard.
class AiRiskAlertsWidget extends ConsumerStatefulWidget {
  const AiRiskAlertsWidget({super.key});

  @override
  ConsumerState<AiRiskAlertsWidget> createState() =>
      _AiRiskAlertsWidgetState();
}

class _AiRiskAlertsWidgetState extends ConsumerState<AiRiskAlertsWidget> {
  bool _isLoading = true;
  List<_EmployeeRisk> _risks = [];
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final sheets = await ref.read(teamGoalsProvider.future);
      final List<_EmployeeRisk> allRisks = [];

      for (final sheet in sheets) {
        try {
          final risks = await ref.read(aiApiProvider).getRiskPrediction(
                goalId: sheet.id,
                quarter: 'Q1',
              );
          final atRisk = risks
              .where((r) => r.riskLevel == 'high' || r.riskLevel == 'medium')
              .toList();
          if (atRisk.isNotEmpty) {
            allRisks.add(_EmployeeRisk(
              employeeName: sheet.employeeName,
              goalId: sheet.id,
              risks: atRisk,
            ));
          }
        } catch (_) {
          // Skip individual goal errors silently.
        }
      }

      if (!mounted) return;
      setState(() => _risks = allRisks);
    } catch (_) {
      // Silently handle — risk alerts are non-critical.
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _card(
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Analysing team goal risks...',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.kTextSecondary),
            ),
          ],
        ),
      );
    }

    if (_risks.isEmpty) {
      return _card(
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.kSuccess, size: 20),
            const SizedBox(width: 10),
            Text(
              'No at-risk goals detected in your team',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.kSuccess),
            ),
          ],
        ),
      );
    }

    final totalAtRisk = _risks.fold<int>(0, (sum, e) => sum + e.risks.length);

    return _card(
      borderColor: AppColors.kWarning.withValues(alpha: 0.4),
      bgColor: AppColors.kWarning.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header.
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.kWarning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠ AI Risk Alert — $totalAtRisk Goal${totalAtRisk > 1 ? 's' : ''} At Risk',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kTextPrimary),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/manager/analytics'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.kBrandPrimary,
                  textStyle: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: const Text('View Details →'),
              ),
            ],
          ),
          Text(
            'Based on Q1 trajectory analysis via Gemini',
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.kTextSecondary),
          ),
          const SizedBox(height: 12),
          // Risk rows.
          ..._risks.map((emp) => _buildEmployeeRisks(emp)),
        ],
      ),
    );
  }

  Widget _buildEmployeeRisks(_EmployeeRisk emp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: emp.risks.map((r) {
        final key = '${emp.goalId}_${r.goalItemId}';
        final isExpanded = _expanded.contains(key);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.kCardBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppColors.kBorder.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Employee avatar.
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.kBrandPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emp.employeeName.isNotEmpty
                          ? emp.employeeName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.kBrandPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.employeeName,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.kTextSecondary),
                        ),
                        Text(
                          r.goalTitle,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.kTextPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RiskBadge(level: r.riskLevel),
                  if (r.recommendation != null)
                    GestureDetector(
                      onTap: () => setState(() {
                        if (isExpanded) {
                          _expanded.remove(key);
                        } else {
                          _expanded.add(key);
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                          color: AppColors.kTextSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              if (r.recommendation != null && isExpanded) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.kInfo.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡 ', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Text(
                          r.recommendation!,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.kTextPrimary,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _card({
    required Widget child,
    Color? borderColor,
    Color? bgColor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: borderColor ??
                AppColors.kBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Risk Badge ────────────────────────────────────────────────────────────────

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.level});
  final String level;

  Color get _color => switch (level) {
        'high' => AppColors.kDanger,
        'medium' => AppColors.kWarning,
        _ => AppColors.kSuccess,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level[0].toUpperCase() + level.substring(1),
        style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _color),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _EmployeeRisk {
  final String employeeName;
  final String goalId;
  final List<GoalRiskItem> risks;

  _EmployeeRisk({
    required this.employeeName,
    required this.goalId,
    required this.risks,
  });
}
