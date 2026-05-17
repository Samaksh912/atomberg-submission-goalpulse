import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/status_badge.dart';
import 'goals_provider.dart';

/// Read-only view for approved / locked / submitted goal sheets.
class GoalSheetViewPage extends ConsumerStatefulWidget {
  const GoalSheetViewPage({super.key});

  @override
  ConsumerState<GoalSheetViewPage> createState() => _GoalSheetViewPageState();
}

class _GoalSheetViewPageState extends ConsumerState<GoalSheetViewPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(goalSheetProvider.notifier).fetchGoalSheet();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheetAsync = ref.watch(goalSheetProvider);
    final sheet = sheetAsync.valueOrNull;

    return AppShell(
      pageTitle: 'My Goals',
      role: UserRole.employee,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : sheet == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined,
                          size: 64,
                          color: AppColors.kTextSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('No goal sheet found.',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              color: AppColors.kTextSecondary)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/employee/goals'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create Goals'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kBrandPrimary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildSheetView(context, sheet),
    );
  }

  Widget _buildSheetView(BuildContext context, dynamic sheet) {
    final goals = sheet.goals;
    final isApproved = sheet.sheetStatus == 'approved';
    final isLocked = sheet.sheetStatus == 'locked';
    final canEdit = sheet.sheetStatus == 'draft' || sheet.sheetStatus == 'returned';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status banner ──────────────────────────────────────────
          if (isApproved || isLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.kSuccess.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.kSuccess.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.kSuccess, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Approved${sheet.approvedAt != null ? ' on ${_formatDate(sheet.approvedAt!)}' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.kSuccess,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (sheet.sheetStatus == 'submitted')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.kInfo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.kInfo.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      color: AppColors.kInfo, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Submitted — awaiting manager approval',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.kInfo),
                    ),
                  ),
                ],
              ),
            ),

          // ── Header ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text('Goal Sheet — FY 2025',
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.kTextPrimary)),
              ),
              StatusBadge(status: sheet.sheetStatus),
              const SizedBox(width: 12),
              if (canEdit)
                ElevatedButton.icon(
                  onPressed: () => context.go('/employee/goals'),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Goals'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kBrandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Goals table ────────────────────────────────────────────
          Container(
            width: double.infinity,
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(AppColors.kNeutral100),
                headingTextStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.kTextSecondary),
                dataTextStyle: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.kTextPrimary),
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Thrust Area')),
                  DataColumn(label: Text('Goal Title')),
                  DataColumn(label: Text('UoM')),
                  DataColumn(label: Text('Target')),
                  DataColumn(label: Text('Weightage')),
                ],
                rows: List.generate(goals.length, (i) {
                  final g = goals[i];
                  return DataRow(cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(Text(g.thrustArea)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(g.title,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (g.isShared) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.kInfo.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Shared',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.kInfo)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    DataCell(Text(_uomLabel(g.uomType))),
                    DataCell(Text('${g.target}')),
                    DataCell(
                      Text('${g.weightage.toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600)),
                    ),
                  ]);
                }),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Quarterly Actuals stub ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.kCardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.kBorder.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quarterly Actuals',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.kTextPrimary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_view_month_rounded,
                        size: 40,
                        color: AppColors.kTextSecondary.withValues(alpha: 0.3)),
                    const SizedBox(width: 12),
                    Text(
                      'Quarterly check-in data will appear here once the cycle progresses.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.kTextSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _uomLabel(String uom) => switch (uom) {
        'numeric_max' => '↑ Numeric',
        'numeric_min' => '↓ Numeric',
        'percent_max' => '↑ %',
        'percent_min' => '↓ %',
        'timeline' => 'Timeline',
        'zero' => 'Zero',
        _ => uom,
      };
}
