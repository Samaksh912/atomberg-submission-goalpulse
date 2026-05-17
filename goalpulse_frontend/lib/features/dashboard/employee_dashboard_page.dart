import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/status_badge.dart';
import '../employee/goals/goals_provider.dart';

/// Employee dashboard — shows real goal data and quick-action cards.
class EmployeeDashboardPage extends ConsumerStatefulWidget {
  const EmployeeDashboardPage({super.key});

  @override
  ConsumerState<EmployeeDashboardPage> createState() =>
      _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState
    extends ConsumerState<EmployeeDashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(goalSheetProvider.notifier).fetchGoalSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetAsync = ref.watch(goalSheetProvider);
    final sheet = sheetAsync.valueOrNull;

    final sheetStatus = sheet?.sheetStatus ?? 'none';
    final goalCount = sheet?.goals.length ?? 0;
    final totalWeight = sheet?.totalWeightage ?? 0;

    return AppShell(
      pageTitle: 'Dashboard',
      role: UserRole.employee,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Welcome header ──────────────────────────────────────
            Text('Welcome back 👋',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.kTextPrimary)),
            const SizedBox(height: 4),
            Text('Here\'s an overview of your goal sheet.',
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
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _kpiBox(
                    crossCount,
                    constraints.maxWidth,
                    KpiCard(
                      label: 'Goal Sheet Status',
                      value: _statusLabel(sheetStatus),
                      icon: Icons.assignment_outlined,
                      iconColor: AppColors.kBrandPrimary,
                    ),
                  ),
                  _kpiBox(
                    crossCount,
                    constraints.maxWidth,
                    KpiCard(
                      label: 'Total Goals',
                      value: '$goalCount',
                      icon: Icons.flag_outlined,
                      iconColor: AppColors.kInfo,
                    ),
                  ),
                  _kpiBox(
                    crossCount,
                    constraints.maxWidth,
                    KpiCard(
                      label: 'Total Weightage',
                      value: '${totalWeight.toStringAsFixed(0)}%',
                      icon: Icons.balance_outlined,
                      iconColor: totalWeight == 100
                          ? AppColors.kSuccess
                          : AppColors.kWarning,
                    ),
                  ),
                  _kpiBox(
                    crossCount,
                    constraints.maxWidth,
                    const KpiCard(
                      label: 'Active Window',
                      value: 'Q1 Check-in Open',
                      icon: Icons.calendar_today_outlined,
                      iconColor: AppColors.kSuccess,
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 24),

            // ── Row 2: Action cards ─────────────────────────────────
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final children = [
                _GoalStatusCard(
                  sheetStatus: sheetStatus,
                  onAction: () {
                    if (sheetStatus == 'approved' ||
                        sheetStatus == 'locked') {
                      context.go('/employee/goals/view');
                    } else {
                      context.go('/employee/goals');
                    }
                  },
                ),
                const _NotificationsCard(),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children
                      .map((c) => Expanded(child: c))
                      .toList()
                    ..insert(
                        1,
                        const Expanded(
                            flex: 0, child: SizedBox(width: 16))),
                );
              }
              return Column(children: children);
            }),
          ],
        ),
      ),
    );
  }

  Widget _kpiBox(int crossCount, double maxWidth, Widget child) {
    final w = (maxWidth - (crossCount - 1) * 16) / crossCount;
    return SizedBox(width: w, child: child);
  }

  String _statusLabel(String s) => switch (s) {
        'draft' => 'Draft',
        'submitted' => 'Submitted',
        'approved' => 'Approved',
        'returned' => 'Returned',
        'locked' => 'Locked',
        _ => 'Not Started',
      };
}

// ── Goal Status Card ─────────────────────────────────────────────────────

class _GoalStatusCard extends StatelessWidget {
  const _GoalStatusCard({required this.sheetStatus, required this.onAction});

  final String sheetStatus;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final step = _currentStep(sheetStatus);

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
              const Icon(Icons.track_changes_rounded,
                  color: AppColors.kBrandPrimary, size: 22),
              const SizedBox(width: 10),
              Text('Goal Sheet Workflow',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kTextPrimary)),
              const Spacer(),
              StatusBadge(status: sheetStatus),
            ],
          ),
          const SizedBox(height: 16),

          // Steps.
          ...List.generate(4, (i) {
            final labels = [
              'Create Goals',
              'Submit for Approval',
              'Manager Review',
              'Approved / Locked',
            ];
            final isActive = i == step;
            final isDone = i < step;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? AppColors.kSuccess
                          : isActive
                              ? AppColors.kBrandPrimary
                              : AppColors.kNeutral100,
                    ),
                    alignment: Alignment.center,
                    child: isDone
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text('${i + 1}',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? Colors.white
                                    : AppColors.kTextSecondary)),
                  ),
                  const SizedBox(width: 10),
                  Text(labels[i],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive
                            ? AppColors.kBrandPrimary
                            : isDone
                                ? AppColors.kSuccess
                                : AppColors.kTextSecondary,
                      )),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kBrandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(_actionLabel(sheetStatus)),
            ),
          ),
        ],
      ),
    );
  }

  int _currentStep(String s) => switch (s) {
        'draft' || 'returned' => 0,
        'submitted' => 2,
        'approved' || 'locked' => 3,
        _ => 0,
      };

  String _actionLabel(String s) => switch (s) {
        'draft' || 'returned' => 'Edit Goal Sheet',
        'submitted' => 'View Submitted Sheet',
        'approved' || 'locked' => 'View Approved Goals',
        _ => 'Create Goal Sheet',
      };
}

// ── Notifications Card ───────────────────────────────────────────────────

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard();

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
              const Icon(Icons.notifications_outlined,
                  color: AppColors.kBrandPrimary, size: 22),
              const SizedBox(width: 10),
              Text('Recent Notifications',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kTextPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          _notifTile(Icons.flag_outlined, 'Goal setting window is now open.',
              '2 hours ago'),
          _notifTile(Icons.calendar_today_outlined,
              'FY 2025 cycle has started.', '1 day ago'),
          _notifTile(Icons.person_outline, 'Welcome to GoalPulse!', '3 days ago'),
        ],
      ),
    );
  }

  Widget _notifTile(IconData icon, String text, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
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
                Text(text,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.kTextPrimary)),
                Text(time,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.kTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
