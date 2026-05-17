import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_shell.dart';
import '../../analytics/analytics_provider.dart';
import '../admin_provider.dart';
import '../../../widgets/chart_widgets.dart';

const _cycleId = 'cycle_2025';
const _quarters = ['Q1', 'Q2', 'Q3', 'Q4'];

class OrgAnalyticsPage extends ConsumerWidget {
  const OrgAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync =
        ref.watch(completionDashboardProvider((_cycleId, null)));
    final trendsAsync = ref.watch(qoqTrendsProvider(_cycleId));
    final distAsync = ref.watch(goalDistributionProvider(_cycleId));
    final mgrsAsync = ref.watch(managerEffectivenessProvider(_cycleId));
    final statsAsync = ref.watch(orgStatsProvider);

    return AppShell(
      pageTitle: 'Organisation Analytics',
      role: UserRole.admin,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Organisation Analytics',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.kTextPrimary)),
            const SizedBox(height: 20),

            // ── Row 1: KPI cards ────────────────────────────────────────
            statsAsync.when(
              loading: () => _skeleton(80),
              error: (_, __) => const SizedBox(),
              data: (stats) => Row(
                children: [
                  _KpiCard('Total Employees', '${stats.totalEmployees}',
                      Icons.people_alt_rounded, AppColors.kBrandPrimary),
                  const SizedBox(width: 12),
                  _KpiCard('Goals Submitted', '${stats.goalsSubmitted}',
                      Icons.upload_file_rounded, AppColors.kInfo),
                  const SizedBox(width: 12),
                  _KpiCard('Goals Approved', '${stats.goalsApproved}',
                      Icons.verified_rounded, AppColors.kSuccess),
                  const SizedBox(width: 12),
                  _KpiCard('Pending', '${stats.pendingApprovals}',
                      Icons.hourglass_empty_rounded, AppColors.kWarning),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Row 2: Department × Quarter heatmap ─────────────────────
            dashAsync.when(
              loading: () => _skeleton(280),
              error: (_, __) => const SizedBox(),
              data: (dash) {
                // Group employees by department.
                final deptMap = <String, List<EmployeeCompletion>>{};
                for (final e in dash.employees) {
                  final dept = e.department.isNotEmpty ? e.department : 'Other';
                  deptMap.putIfAbsent(dept, () => []).add(e);
                }
                final depts = deptMap.keys.toList()..sort();
                final heatRows = depts.map((d) {
                  final members = deptMap[d]!;
                  return _quarters.map((q) {
                    final done = members
                        .where((e) => e.checkinsCompleted[q] == true)
                        .length;
                    return members.isNotEmpty
                        ? done / members.length * 100
                        : null;
                  }).toList();
                }).toList();

                return GoalPulseHeatmap(
                  title: 'Department × Quarter Check-In Rates',
                  rowLabels: depts,
                  columnLabels: _quarters,
                  values: heatRows,
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Row 3: Line + Doughnut ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 55,
                  child: trendsAsync.when(
                    loading: () => _skeleton(240),
                    error: (_, __) => const SizedBox(),
                    data: (t) => GoalPulseLineChart(
                      title: 'QoQ Organisation Trends',
                      labels: t.quarters,
                      series: [t.avgScores, t.goalCompletionRates],
                      seriesLabels: const [
                        'Avg Progress Score',
                        'Check-In Completion %'
                      ],
                      seriesColors: const [
                        AppColors.kBrandPrimary,
                        AppColors.kSuccess
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 45,
                  child: distAsync.when(
                    loading: () => _skeleton(240),
                    error: (_, __) => const SizedBox(),
                    data: (dist) {
                      final entries = dist.byThrustArea.entries.toList();
                      final palette = [
                        AppColors.kBrandPrimary,
                        AppColors.kBrandSecondary,
                        AppColors.kSuccess,
                        AppColors.kWarning,
                        AppColors.kInfo,
                        AppColors.kDanger,
                      ];
                      return GoalPulseDoughnutChart(
                        title: 'Goal Distribution by Thrust Area',
                        labels: entries.map((e) => e.key).toList(),
                        values:
                            entries.map((e) => e.value.toDouble()).toList(),
                        colors: List.generate(
                            entries.length,
                            (i) => palette[i % palette.length]),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Row 4: Manager Effectiveness ────────────────────────────
            _sectionTitle('Manager Effectiveness'),
            const SizedBox(height: 12),
            mgrsAsync.when(
              loading: () => _skeleton(200),
              error: (e, _) =>
                  Text('Error: $e', style: const TextStyle(color: AppColors.kDanger)),
              data: (managers) => managers.isEmpty
                  ? _emptyBox('No manager data yet.')
                  : _ManagerEffectivenessChart(managers: managers),
            ),
            const SizedBox(height: 20),

            // ── Row 5: Goal Distribution by UoM ────────────────────────
            distAsync.when(
              loading: () => _skeleton(200),
              error: (_, __) => const SizedBox(),
              data: (dist) {
                final entries = dist.byUomType.entries.toList();
                final labels = entries.map((e) => _uomLabel(e.key)).toList();
                final planned = List.filled(entries.length, 1.0);
                final actual = entries.map((e) => e.value.toDouble()).toList();
                return GoalPulseBarChart(
                  title: 'Goal Distribution by UoM Type',
                  labels: labels,
                  plannedValues: planned,
                  actualValues: actual,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.kTextPrimary));

  Widget _skeleton(double h) => Container(
      height: h,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
          color: AppColors.kNeutral100,
          borderRadius: BorderRadius.circular(12)));

  Widget _emptyBox(String msg) => Container(
        height: 80,
        alignment: Alignment.center,
        child: Text(msg,
            style: GoogleFonts.inter(color: AppColors.kTextSecondary)),
      );

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

// ── Manager Effectiveness Horizontal Bar ──────────────────────────────────────

class _ManagerEffectivenessChart extends StatelessWidget {
  const _ManagerEffectivenessChart({required this.managers});
  final List<ManagerEffectivenessItem> managers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.kBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: managers
            .map((m) => _ManagerBar(item: m))
            .toList(),
      ),
    );
  }
}

class _ManagerBar extends StatelessWidget {
  const _ManagerBar({required this.item});
  final ManagerEffectivenessItem item;

  Color get _barColor {
    if (item.checkinRate >= 80) return AppColors.kSuccess;
    if (item.checkinRate >= 50) return AppColors.kWarning;
    return AppColors.kDanger;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  item.name,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.kTextPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: LayoutBuilder(builder: (_, constraints) {
                  final barW =
                      constraints.maxWidth * (item.checkinRate / 100);
                  return Stack(
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.kNeutral100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        width: barW.clamp(0, constraints.maxWidth),
                        height: 22,
                        decoration: BoxDecoration(
                          color: _barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${item.checkinRate.toStringAsFixed(0)}%  ·  avg ${item.avgScore.toStringAsFixed(0)} pts  ·  team ${item.teamSize}',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: item.checkinRate > 30
                                      ? Colors.white
                                      : AppColors.kTextPrimary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.kCardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.kBorder.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.kTextPrimary)),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.kTextSecondary)),
          ],
        ),
      ),
    );
  }
}
