import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/loading_skeleton.dart';
import '../../manager/approvals/approvals_provider.dart';
import '../../employee/checkins/checkin_provider.dart';

/// Manager view — lists team members and their check-in status per quarter.
class TeamCheckinsPage extends ConsumerStatefulWidget {
  const TeamCheckinsPage({super.key});

  @override
  ConsumerState<TeamCheckinsPage> createState() => _TeamCheckinsPageState();
}

class _TeamCheckinsPageState extends ConsumerState<TeamCheckinsPage> {
  String _quarter = 'Q1';

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamGoalsProvider);

    return AppShell(
      pageTitle: 'Team Check-Ins',
      role: UserRole.manager,
      child: teamAsync.when(
        loading: () => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: List.generate(
                3,
                (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: LoadingSkeletonCard(),
                    )),
          ),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: GoogleFonts.inter(color: AppColors.kDanger)),
        ),
        data: (sheets) {
          // Only show approved/locked sheets (eligible for check-ins).
          final eligible = sheets
              .where((s) =>
                  s.sheetStatus == 'approved' || s.sheetStatus == 'locked')
              .toList();

          return Column(
            children: [
              // Quarter tabs.
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  children: ['Q1', 'Q2', 'Q3', 'Q4'].map((q) {
                    final isActive = q == _quarter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(q),
                        selected: isActive,
                        onSelected: (_) =>
                            setState(() => _quarter = q),
                        selectedColor: AppColors.kBrandPrimary,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : AppColors.kTextPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Team list.
              Expanded(
                child: eligible.isEmpty
                    ? const EmptyStateWidget(
                        title: 'No Eligible Sheets',
                        subtitle:
                            'No approved goal sheets yet for check-ins.',
                        icon: Icons.pending_outlined,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: eligible.length,
                        itemBuilder: (context, i) {
                          return _TeamMemberCheckinCard(
                            sheet: eligible[i],
                            quarter: _quarter,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamMemberCheckinCard extends ConsumerWidget {
  const _TeamMemberCheckinCard({
    required this.sheet,
    required this.quarter,
  });

  final GoalSheetSummary sheet;
  final String quarter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinsAsync = ref.watch(checkinsByGoalProvider(sheet.id));

    return checkinsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: LoadingSkeletonCard(),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (checkins) {
        final checkin =
            checkins.where((c) => c.quarter == quarter).firstOrNull;
        final status = checkin?.status ?? 'pending';
        final statusLabel = switch (status) {
          'actuals_submitted' => 'Actuals Submitted',
          'manager_reviewed' => 'Reviewed',
          _ => 'Pending',
        };
        final statusColor = switch (status) {
          'actuals_submitted' => AppColors.kWarning,
          'manager_reviewed' => AppColors.kSuccess,
          _ => AppColors.kTextSecondary,
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.kCardBackground,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.kBorder.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.kBrandPrimary,
                      AppColors.kBrandSecondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(sheet.employeeName),
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),

              // Info.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheet.employeeName.isNotEmpty
                          ? sheet.employeeName
                          : sheet.employeeEmail,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.kTextPrimary),
                    ),
                    if (sheet.employeeDepartment.isNotEmpty)
                      Text(sheet.employeeDepartment,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.kTextSecondary)),
                  ],
                ),
              ),

              // Status badge.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusLabel,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
              const SizedBox(width: 12),

              // Overall score if submitted.
              if (checkin != null) ...[
                Text(
                  '${checkin.overallScore.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: checkin.overallScore >= 80
                        ? AppColors.kSuccess
                        : checkin.overallScore >= 50
                            ? AppColors.kWarning
                            : AppColors.kDanger,
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Review button.
              ElevatedButton(
                onPressed: checkin != null &&
                        status == 'actuals_submitted'
                    ? () {
                        context.go(
                            '/manager/checkins/${checkin.id}');
                      }
                    : checkin != null &&
                            status == 'manager_reviewed'
                        ? () {
                            context.go(
                                '/manager/checkins/${checkin.id}');
                          }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == 'actuals_submitted'
                      ? AppColors.kBrandPrimary
                      : AppColors.kNeutral100,
                  foregroundColor: status == 'actuals_submitted'
                      ? Colors.white
                      : AppColors.kTextSecondary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  status == 'actuals_submitted'
                      ? 'Review'
                      : status == 'manager_reviewed'
                          ? 'View'
                          : 'Pending',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}
