import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/toast_notification.dart';
import '../../analytics/analytics_provider.dart';
import '../../../widgets/chart_widgets.dart';

const _cycleId = 'cycle_2025';
const _quarters = ['Q1', 'Q2', 'Q3', 'Q4'];

class TeamAnalyticsPage extends ConsumerStatefulWidget {
  const TeamAnalyticsPage({super.key});

  @override
  ConsumerState<TeamAnalyticsPage> createState() => _TeamAnalyticsPageState();
}

class _TeamAnalyticsPageState extends ConsumerState<TeamAnalyticsPage> {
  String? _selectedQuarter;

  @override
  Widget build(BuildContext context) {
    final dashAsync =
        ref.watch(completionDashboardProvider((_cycleId, _selectedQuarter)));
    final trendsAsync = ref.watch(qoqTrendsProvider(_cycleId));
    final distAsync = ref.watch(goalDistributionProvider(_cycleId));

    return AppShell(
      pageTitle: 'Team Analytics',
      role: UserRole.manager,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Text('Team Analytics',
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.kTextPrimary)),
                const Spacer(),
                // Quarter filter.
                _QuarterFilter(
                  selected: _selectedQuarter,
                  onChanged: (q) => setState(() => _selectedQuarter = q),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _exportReport(),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export Team Report'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Row 1: KPI cards ─────────────────────────────────────────
            dashAsync.when(
              loading: () => _kpiSkeleton(),
              error: (e, _) => _errorWidget('$e'),
              data: (dash) => _buildKpiRow(dash),
            ),
            const SizedBox(height: 20),

            // ── Row 2: Heatmap + Doughnut ─────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: dashAsync.when(
                    loading: () => _skeleton(),
                    error: (_, __) => const SizedBox(),
                    data: (dash) => GoalPulseHeatmap(
                      title: 'Team Check-In Completion',
                      rowLabels:
                          dash.employees.map((e) => e.name).toList(),
                      columnLabels: _quarters,
                      values: dash.employees
                          .map((e) => _quarters
                              .map((q) => e.checkinsCompleted[q] == true
                                  ? 100.0
                                  : 0.0)
                              .toList())
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: distAsync.when(
                    loading: () => _skeleton(),
                    error: (_, __) => const SizedBox(),
                    data: (dist) {
                      final entries = dist.byStatus.entries.toList();
                      return GoalPulseDoughnutChart(
                        title: 'Goal Status Distribution',
                        labels:
                            entries.map((e) => _statusLabel(e.key)).toList(),
                        values:
                            entries.map((e) => e.value.toDouble()).toList(),
                        colors: entries.map((e) => _statusColor(e.key)).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Row 3: QoQ Line Chart ─────────────────────────────────────
            trendsAsync.when(
              loading: () => _skeleton(),
              error: (_, __) => const SizedBox(),
              data: (trends) => GoalPulseLineChart(
                title: 'QoQ Average Score Trend',
                labels: trends.quarters,
                series: [trends.avgScores, trends.goalCompletionRates],
                seriesLabels: const ['Avg Progress Score', 'Check-In Rate %'],
                seriesColors: const [AppColors.kBrandPrimary, AppColors.kSuccess],
              ),
            ),
            const SizedBox(height: 20),

            // ── Row 4: Bar Chart (planned vs actual by quarter) ───────────
            trendsAsync.when(
              loading: () => _skeleton(),
              error: (_, __) => const SizedBox(),
              data: (trends) => GoalPulseBarChart(
                title: 'Planned (100%) vs Actual Progress — by Quarter',
                labels: trends.quarters,
                plannedValues:
                    List.filled(trends.quarters.length, 100.0),
                actualValues: trends.avgScores,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(CompletionDashboard dash) {
    final total = dash.employees.length;
    final approved = dash.employees.where((e) => e.goalApproved).length;
    final onTrack = dash.employees
        .where((e) =>
            _quarters.any((q) => e.checkinsCompleted[q] == true))
        .length;
    final atRisk = total - onTrack;

    return Row(
      children: [
        _KpiCard(
          label: 'Check-In Rate',
          value: '${dash.completionRate.toStringAsFixed(0)}%',
          icon: Icons.checklist_rounded,
          color: AppColors.kBrandPrimary,
        ),
        const SizedBox(width: 12),
        _KpiCard(
          label: 'Goals Approved',
          value: total > 0
              ? '${(approved / total * 100).toStringAsFixed(0)}%'
              : '—',
          icon: Icons.verified_rounded,
          color: AppColors.kSuccess,
        ),
        const SizedBox(width: 12),
        _KpiCard(
          label: 'At Risk',
          value: '$atRisk',
          icon: Icons.warning_amber_rounded,
          color: AppColors.kDanger,
        ),
      ],
    );
  }

  void _exportReport() async {
    try {
      final rows = await ref
          .read(analyticsApiProvider)
          .getAchievementReport(_cycleId, _selectedQuarter);
      if (!mounted) return;
      ToastNotification.showSuccess(
          context, 'Report ready — ${rows.length} rows.');
    } catch (e) {
      if (mounted) ToastNotification.showError(context, 'Export failed: $e');
    }
  }

  Widget _kpiSkeleton() => Row(
        children: List.generate(
            3,
            (_) => Expanded(
                  child: Container(
                    height: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.kNeutral100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )),
      );

  Widget _skeleton() => Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.kNeutral100,
          borderRadius: BorderRadius.circular(12),
        ),
      );

  Widget _errorWidget(String msg) => Container(
        padding: const EdgeInsets.all(12),
        child: Text('Error: $msg',
            style: const TextStyle(color: AppColors.kDanger)),
      );

  String _statusLabel(String s) => switch (s) {
        'draft' => 'Draft',
        'submitted' => 'Submitted',
        'approved' => 'Approved',
        'locked' => 'Locked',
        'returned' => 'Returned',
        _ => s,
      };

  Color _statusColor(String s) => switch (s) {
        'draft' => AppColors.kTextSecondary,
        'submitted' => AppColors.kInfo,
        'approved' || 'locked' => AppColors.kSuccess,
        'returned' => AppColors.kWarning,
        _ => AppColors.kBrandPrimary,
      };
}

// ── Quarter filter ────────────────────────────────────────────────────────────

class _QuarterFilter extends StatelessWidget {
  const _QuarterFilter({required this.selected, required this.onChanged});
  final String? selected;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(null, 'All'),
        ..._quarters.map((q) => _chip(q, q)),
      ],
    );
  }

  Widget _chip(String? val, String label) {
    final isSelected = selected == val;
    return GestureDetector(
      onTap: () => onChanged(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.kBrandPrimary
              : AppColors.kNeutral100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? Colors.white
                    : AppColors.kTextSecondary)),
      ),
    );
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.kCardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.kBorder.withValues(alpha: 0.5)),
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.kTextPrimary)),
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.kTextSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
