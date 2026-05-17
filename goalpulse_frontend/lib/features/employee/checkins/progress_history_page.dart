import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/checkin_model.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/empty_state_widget.dart';
import '../goals/goals_provider.dart';
import 'checkin_provider.dart';

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

                              // AI summary.
                              if (checkin.aiSummary != null) ...[
                                const SizedBox(height: 16),
                                _buildAiSummary(checkin),
                              ],

                              const SizedBox(height: 20),

                              // Chart.
                              Text('Planned vs Actual',
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.kTextPrimary)),
                              const SizedBox(height: 12),
                              _buildChart(checkin),
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

  Widget _buildAiSummary(CheckinRecord c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kBrandSecondary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.kBrandSecondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 16, color: AppColors.kBrandSecondary),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.kBrandSecondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('AI',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.kBrandSecondary)),
              ),
              const SizedBox(width: 8),
              Text('AI Summary',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kBrandSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.aiSummary!,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.kTextPrimary)),
        ],
      ),
    );
  }

  Widget _buildChart(CheckinRecord c) {
    final actuals = c.actuals;
    if (actuals.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 220,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kBorder.withValues(alpha: 0.5)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 110,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= actuals.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 50),
                      child: Text(
                        actuals[idx].goalTitle,
                        style: GoogleFonts.inter(fontSize: 9),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}%',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.kTextSecondary),
                ),
                interval: 25,
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (v) => FlLine(
              color: AppColors.kBorder.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(actuals.length, (i) {
            final a = actuals[i];
            final targetVal = _toDouble(a.target);
            final actualVal = a.progressScore;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: targetVal.clamp(0, 100),
                  color: AppColors.kBrandPrimary.withValues(alpha: 0.3),
                  width: 12,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: actualVal.clamp(0, 100),
                  color: actualVal >= 80
                      ? AppColors.kSuccess
                      : actualVal >= 50
                          ? AppColors.kWarning
                          : AppColors.kDanger,
                  width: 12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}
