import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/kpi_card.dart';
import '../manager/approvals/approvals_provider.dart';
import '../manager/dashboard/widgets/ai_risk_alerts_widget.dart';

/// Manager dashboard — real KPI cards + pending approvals + team activity.
class ManagerDashboardPage extends ConsumerWidget {
  const ManagerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingApprovalsProvider);
    final teamAsync = ref.watch(teamGoalsProvider);

    final pendingCount =
        pendingAsync.valueOrNull?.length ?? 0;
    final teamCount = teamAsync.valueOrNull?.length ?? 0;

    return AppShell(
      pageTitle: 'Dashboard',
      role: UserRole.manager,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Welcome header ──────────────────────────────────────
            Text('Manager Dashboard 🎯',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.kTextPrimary)),
            const SizedBox(height: 4),
            Text('Review and manage your team\'s goal sheets.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.kTextSecondary)),
            const SizedBox(height: 24),

            // ── Row 1: KPI cards ────────────────────────────────────
            LayoutBuilder(builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 900
                  ? 4
                  : constraints.maxWidth > 600
                      ? 2
                      : 1;
              final w = (constraints.maxWidth - (crossCount - 1) * 16) /
                  crossCount;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: w,
                    child: KpiCard(
                      label: 'Pending Approvals',
                      value: '$pendingCount',
                      icon: Icons.pending_actions_rounded,
                      iconColor: pendingCount > 0
                          ? AppColors.kDanger
                          : AppColors.kSuccess,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: KpiCard(
                      label: 'Team Members',
                      value: '$teamCount',
                      icon: Icons.groups_outlined,
                      iconColor: AppColors.kBrandPrimary,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: const KpiCard(
                      label: 'Check-Ins Completed',
                      value: '0 / 0',
                      icon: Icons.fact_check_outlined,
                      iconColor: AppColors.kInfo,
                      subtitle: 'This quarter',
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: const KpiCard(
                      label: 'Goals At Risk',
                      value: '0',
                      icon: Icons.warning_amber_rounded,
                      iconColor: AppColors.kWarning,
                      subtitle: 'At risk',
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),

            // ── Row 1.5: AI Risk Alerts ───────────────────────────
            const AiRiskAlertsWidget(),
            const SizedBox(height: 24),

            // ── Row 2: Cards ────────────────────────────────────────
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final children = [
                _PendingApprovalsCard(
                  pending: pendingAsync.valueOrNull ?? [],
                  onViewAll: () => context.go('/manager/approvals'),
                  onReview: (sheet) {
                    ref.read(selectedGoalProvider.notifier).state = sheet;
                    context.go('/manager/approvals/${sheet.id}');
                  },
                ),
                const _TeamActivityCard(),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 16),
                    Expanded(child: children[1]),
                  ],
                );
              }
              return Column(children: children);
            }),
          ],
        ),
      ),
    );
  }
}

// ── Pending Approvals Card ───────────────────────────────────────────────

class _PendingApprovalsCard extends StatelessWidget {
  const _PendingApprovalsCard({
    required this.pending,
    required this.onViewAll,
    required this.onReview,
  });

  final List<GoalSheetSummary> pending;
  final VoidCallback onViewAll;
  final void Function(GoalSheetSummary) onReview;

  @override
  Widget build(BuildContext context) {
    final items = pending.take(3).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              const Icon(Icons.pending_actions_rounded,
                  color: AppColors.kBrandPrimary, size: 22),
              const SizedBox(width: 10),
              Text('Pending Approvals',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kTextPrimary)),
              const Spacer(),
              if (pending.length > 3)
                TextButton(
                  onPressed: onViewAll,
                  child: Text('View All (${pending.length})',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.kBrandPrimary)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 20, color: AppColors.kSuccess),
                  const SizedBox(width: 8),
                  Text('All caught up! No pending approvals.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.kTextSecondary)),
                ],
              ),
            )
          else
            ...items.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => onReview(s),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.kNeutral100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.kBrandPrimary,
                                  AppColors.kBrandSecondary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _initials(s.employeeName),
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.employeeName.isNotEmpty
                                      ? s.employeeName
                                      : s.employeeEmail,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.kTextPrimary),
                                ),
                                Text('${s.goalCount} goals',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.kTextSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 18, color: AppColors.kTextSecondary),
                        ],
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}

// ── Team Activity Card ───────────────────────────────────────────────────

class _TeamActivityCard extends StatelessWidget {
  const _TeamActivityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  color: AppColors.kBrandPrimary, size: 22),
              const SizedBox(width: 10),
              Text('Team Activity',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kTextPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          _activityTile(Icons.send_rounded, 'Employee goal submitted',
              'A team member submitted their goal sheet.', 'Just now'),
          _activityTile(Icons.flag_outlined, 'Goal setting window open',
              'FY 2025 goal setting is now active.', '1 day ago'),
          _activityTile(Icons.group_add_outlined, 'Team onboarded',
              'All team members have been registered.', '3 days ago'),
        ],
      ),
    );
  }

  Widget _activityTile(
      IconData icon, String title, String sub, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.kBrandPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: AppColors.kBrandPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.kTextPrimary)),
                Text(sub,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.kTextSecondary)),
              ],
            ),
          ),
          Text(time,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.kTextSecondary)),
        ],
      ),
    );
  }
}
