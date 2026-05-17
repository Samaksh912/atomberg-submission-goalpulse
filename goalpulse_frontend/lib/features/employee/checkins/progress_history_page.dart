import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/checkin_model.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/chart_widgets.dart';
import '../../../widgets/empty_state_widget.dart';
import '../goals/goals_provider.dart';
import 'checkin_provider.dart';
import 'widgets/ai_summary_widget.dart';

/// Read-only progress history page showing past check-ins.
class ProgressHistoryPage extends ConsumerStatefulWidget {
  const ProgressHistoryPage({super.key});

  @override
  ConsumerState<ProgressHistoryPage> createState() =>
      _ProgressHistoryPageState();
}

class _ProgressHistoryPageState extends ConsumerState<ProgressHistoryPage> {
  String _quarter = 'Q1';
  bool _isLoading = true;
  List<CheckinRecord> _checkins = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  Future<void> _loadData() async {
    await ref.read(goalSheetProvider.notifier).fetchGoalSheet();
    final sheet = ref.read(goalSheetProvider).valueOrNull;
    if (sheet != null) {
      _checkins = await ref.read(checkinsByGoalProvider(sheet.id).future);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  CheckinRecord? get _activeCheckin =>
      _checkins.where((c) => c.quarter == _quarter).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final checkin = _activeCheckin;

    return AppShell(
      pageTitle: 'My Progress',
      role: UserRole.employee,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Quarter tabs ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: ['Q1', 'Q2', 'Q3', 'Q4'].map((q) {
                      final isActive = q == _quarter;
                      final hasData =
                          _checkins.any((c) => c.quarter == q);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(q),
                              if (hasData) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.kSuccess,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
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

                // ── Content ──────────────────────────────────────────
                Expanded(
                  child: checkin == null
                      ? const EmptyStateWidget(
                          title: 'No Data Yet',
                          subtitle:
                              'No check-in data available for this quarter.',
                          icon: Icons.timeline_rounded,
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Overall score card.
                              _buildOverallCard(checkin),
                              const SizedBox(height: 20),

                              // Actuals table.
                              _buildActualsTable(checkin),
                              const SizedBox(height: 20),

                              // Manager comment.
                              if (checkin.managerComment != null)
                                _buildManagerComment(checkin),

                              // AI Summary (always shown after submission).
                              const SizedBox(height: 16),
                              AiSummaryWidget(
                                checkinId: checkin.id,
                                quarter: checkin.quarter,
                                initialSummary: checkin.aiSummary,
                              ),

                              const SizedBox(height: 20),

                              // Per-goal bar chart.
                              _buildBarChart(checkin),
                              const SizedBox(height: 20),

                              // QoQ line chart (if multi-quarter data).
                              _buildQoQChart(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverallCard(CheckinRecord c) {
    final score = c.overallScore;
    final color = score >= 80
        ? AppColors.kSuccess
        : score >= 50
            ? AppColors.kWarning
            : AppColors.kDanger;

    return Container(
      width: double.infinity,
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
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Text('${score.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overall ${c.quarter} Score',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kTextPrimary)),
              const SizedBox(height: 4),
              Text(
                c.status == 'manager_reviewed'
                    ? 'Reviewed by manager'
                    : 'Pending review',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActualsTable(CheckinRecord c) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kBorder.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.kNeutral100),
          headingTextStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.kTextSecondary),
          dataTextStyle:
              GoogleFonts.inter(fontSize: 13, color: AppColors.kTextPrimary),
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Goal')),
            DataColumn(label: Text('Target')),
            DataColumn(label: Text('Actual')),
            DataColumn(label: Text('Score')),
            DataColumn(label: Text('Status')),
          ],
          rows: c.actuals.map((a) {
            final score = a.progressScore;
            final color = score >= 80
                ? AppColors.kSuccess
                : score >= 50
                    ? AppColors.kWarning
                    : AppColors.kDanger;
            return DataRow(cells: [
              DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(a.goalTitle,
                      overflow: TextOverflow.ellipsis))),
              DataCell(Text('${a.target}')),
              DataCell(Text('${a.actualAchievement}')),
              DataCell(Text('${score.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, color: color))),
              DataCell(_statusChip(a.status)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final label = switch (status) {
      'on_track' => 'On Track',
      'completed' => 'Completed',
      _ => 'Not Started',
    };
    final color = switch (status) {
      'on_track' => AppColors.kInfo,
      'completed' => AppColors.kSuccess,
      _ => AppColors.kTextSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildManagerComment(CheckinRecord c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kBrandPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.kBrandPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.comment_outlined,
                  size: 16, color: AppColors.kBrandPrimary),
              const SizedBox(width: 8),
              Text('Manager\'s Comment',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kBrandPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.managerComment!,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.kTextPrimary)),
        ],
      ),
    );
  }

  /// Grouped bar chart: target score (100%) vs actual progress score per goal.
  Widget _buildBarChart(CheckinRecord c) {
    final actuals = c.actuals;
    if (actuals.isEmpty) return const SizedBox.shrink();

    final labels = actuals.map((a) {
      final t = a.goalTitle;
      return t.length > 14 ? '${t.substring(0, 12)}…' : t;
    }).toList();

    return GoalPulseBarChart(
      title: 'Planned (100%) vs Actual — $_quarter',
      labels: labels,
      plannedValues: List.filled(actuals.length, 100.0),
      actualValues: actuals.map((a) => a.progressScore.clamp(0.0, 100.0)).toList(),
    );
  }

  /// Line chart showing my average score across all submitted quarters.
  Widget _buildQoQChart() {
    const quarters = ['Q1', 'Q2', 'Q3', 'Q4'];
    final scores = quarters.map((q) {
      final ci = _checkins.where((c) => c.quarter == q).firstOrNull;
      if (ci == null || ci.actuals.isEmpty) return 0.0;
      final sum = ci.actuals.fold(0.0, (acc, a) => acc + a.progressScore);
      return (sum / ci.actuals.length).clamp(0.0, 100.0);
    }).toList();

    // Only show if there's at least one non-zero data point.
    if (scores.every((s) => s == 0)) return const SizedBox.shrink();

    return GoalPulseLineChart(
      title: 'My QoQ Progress Trend',
      labels: quarters,
      series: [scores],
      seriesLabels: const ['Avg Score'],
      seriesColors: const [AppColors.kBrandPrimary],
    );
  }
}
