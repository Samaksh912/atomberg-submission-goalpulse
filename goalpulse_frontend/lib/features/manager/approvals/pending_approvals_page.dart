import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/loading_skeleton.dart';
import 'approvals_provider.dart';

/// List page showing goal sheets awaiting manager approval.
class PendingApprovalsPage extends ConsumerWidget {
  const PendingApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalsAsync = ref.watch(pendingApprovalsProvider);

    return AppShell(
      pageTitle: 'Pending Approvals',
      role: UserRole.manager,
      child: approvalsAsync.when(
        loading: () => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LoadingSkeletonCard(),
              ),
            ),
          ),
        ),
        error: (e, _) => Center(
          child: Text('Error loading approvals: $e',
              style: GoogleFonts.inter(color: AppColors.kDanger)),
        ),
        data: (approvals) {
          if (approvals.isEmpty) {
            return const EmptyStateWidget(
              title: 'All Caught Up!',
              subtitle: 'No goal sheets awaiting your approval.',
              icon: Icons.check_circle_outline_rounded,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: approvals.length,
            itemBuilder: (context, index) {
              final sheet = approvals[index];
              return _ApprovalCard(
                sheet: sheet,
                onReview: () {
                  ref.read(selectedGoalProvider.notifier).state = sheet;
                  context.go('/manager/approvals/${sheet.id}');
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.sheet, required this.onReview});

  final GoalSheetSummary sheet;
  final VoidCallback onReview;

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
      child: Row(
        children: [
          // Avatar.
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.kBrandPrimary, AppColors.kBrandSecondary],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(sheet.employeeName),
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),

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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.kTextPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  sheet.employeeDepartment.isNotEmpty
                      ? sheet.employeeDepartment
                      : sheet.employeeEmail,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.kTextSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 13,
                        color: AppColors.kTextSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      sheet.submittedAt != null
                          ? 'Submitted ${_timeAgo(sheet.submittedAt!)}'
                          : 'Submitted',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.kTextSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chips.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _chip('${sheet.goalCount} Goals', AppColors.kBrandPrimary),
                  const SizedBox(width: 6),
                  _chip(
                    '${sheet.totalWeightage.toStringAsFixed(0)}%',
                    sheet.totalWeightage == 100
                        ? AppColors.kSuccess
                        : AppColors.kWarning,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.rate_review_outlined, size: 16),
                label: const Text('Review'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kBrandPrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return '${diff.inMinutes}m ago';
    } catch (_) {
      return iso;
    }
  }
}
