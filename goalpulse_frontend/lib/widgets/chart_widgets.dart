import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// Smooth curved multi-series line chart.
class GoalPulseLineChart extends StatelessWidget {
  const GoalPulseLineChart({
    super.key,
    required this.title,
    required this.labels,
    required this.series,
    required this.seriesLabels,
    required this.seriesColors,
    this.height = 240,
  });

  final String title;
  final List<String> labels;
  final List<List<double>> series;
  final List<String> seriesLabels;
  final List<Color> seriesColors;
  final double height;

  bool get _isEmpty =>
      series.isEmpty || series.every((s) => s.every((v) => v == 0));

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: title,
      legend: _buildLegend(),
      child: _isEmpty ? _EmptyState() : _buildChart(),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      children: List.generate(seriesLabels.length, (i) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 3,
              decoration: BoxDecoration(
                color: seriesColors[i % seriesColors.length],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(seriesLabels[i],
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.kTextSecondary)),
          ],
        );
      }),
    );
  }

  Widget _buildChart() {
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0xFFE5E7EB),
              strokeWidth: 1,
            ),
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= labels.length) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[idx],
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.kTextSecondary)),
                  );
                },
                reservedSize: 28,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (val, _) => Text(
                  '${val.toInt()}',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.kTextSecondary),
                ),
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final label = s.x.toInt() < labels.length
                    ? labels[s.x.toInt()]
                    : '';
                return LineTooltipItem(
                  '$label: ${s.y.toStringAsFixed(1)}',
                  GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: seriesColors[s.barIndex % seriesColors.length]),
                );
              }).toList(),
            ),
          ),
          lineBarsData: List.generate(series.length, (i) {
            final color = seriesColors[i % seriesColors.length];
            final pts = series[i];
            return LineChartBarData(
              spots: List.generate(
                  pts.length, (j) => FlSpot(j.toDouble(), pts[j])),
              isCurved: true,
              color: color,
              barWidth: 2.5,
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.08),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3.5,
                  color: color,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Bar Chart ─────────────────────────────────────────────────────────────────

/// Grouped bar chart with Planned vs Actual.
class GoalPulseBarChart extends StatelessWidget {
  const GoalPulseBarChart({
    super.key,
    required this.title,
    required this.labels,
    required this.plannedValues,
    required this.actualValues,
    this.height = 240,
  });

  final String title;
  final List<String> labels;
  final List<double> plannedValues;
  final List<double> actualValues;
  final double height;

  bool get _isEmpty => labels.isEmpty;

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: title,
      legend: _buildLegend(),
      child: _isEmpty ? _EmptyState() : _buildChart(),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendDot(AppColors.kBrandPrimary, 'Planned'),
        const SizedBox(width: 16),
        _legendDot(AppColors.kSuccess, 'Actual'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.kTextSecondary)),
        ],
      );

  Widget _buildChart() {
    final groups = List.generate(labels.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: plannedValues[i],
            color: AppColors.kBrandPrimary,
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: actualValues.length > i ? actualValues[i] : 0,
            color: AppColors.kSuccess,
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
        groupVertically: false,
        barsSpace: 4,
      );
    });

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          barGroups: groups,
          groupsSpace: 20,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
                color: Color(0xFFE5E7EB), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= labels.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[idx],
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.kTextSecondary)),
                  );
                },
                reservedSize: 28,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (val, _) => Text(
                  '${val.toInt()}',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.kTextSecondary),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, rodIdx) {
                final label = group.x < labels.length
                    ? labels[group.x]
                    : '';
                final type = rodIdx == 0 ? 'Planned' : 'Actual';
                return BarTooltipItem(
                  '$label $type\n${rod.toY.toStringAsFixed(1)}',
                  GoogleFonts.inter(
                      fontSize: 11, color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Doughnut Chart ────────────────────────────────────────────────────────────

class GoalPulseDoughnutChart extends StatefulWidget {
  const GoalPulseDoughnutChart({
    super.key,
    required this.title,
    required this.labels,
    required this.values,
    required this.colors,
    this.height = 200,
  });

  final String title;
  final List<String> labels;
  final List<double> values;
  final List<Color> colors;
  final double height;

  @override
  State<GoalPulseDoughnutChart> createState() =>
      _GoalPulseDoughnutChartState();
}

class _GoalPulseDoughnutChartState extends State<GoalPulseDoughnutChart> {
  int _touchedIdx = -1;

  bool get _isEmpty =>
      widget.values.isEmpty || widget.values.every((v) => v == 0);

  double get _total => widget.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: widget.title,
      child: _isEmpty
          ? _EmptyState()
          : Column(
              children: [
                SizedBox(
                  height: widget.height,
                  child: PieChart(
                    PieChartData(
                      sections: _buildSections(),
                      centerSpaceRadius: widget.height * 0.3,
                      sectionsSpace: 2,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            _touchedIdx = response
                                    ?.touchedSection
                                    ?.touchedSectionIndex ??
                                -1;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildLegend(),
              ],
            ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    return List.generate(widget.values.length, (i) {
      final isTouched = i == _touchedIdx;
      final color =
          widget.colors[i % widget.colors.length];
      final pct = _total > 0
          ? (widget.values[i] / _total * 100)
          : 0.0;
      return PieChartSectionData(
        value: widget.values[i],
        color: color,
        radius: isTouched ? 60 : 50,
        title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white),
      );
    });
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: List.generate(widget.labels.length, (i) {
        final pct = _total > 0
            ? (widget.values[i] / _total * 100)
            : 0.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: widget.colors[i % widget.colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.labels[i]} (${pct.toStringAsFixed(0)}%)',
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.kTextSecondary),
            ),
          ],
        );
      }),
    );
  }
}

// ── Heatmap Widget ────────────────────────────────────────────────────────────

class GoalPulseHeatmap extends StatelessWidget {
  const GoalPulseHeatmap({
    super.key,
    required this.title,
    required this.rowLabels,
    required this.columnLabels,
    required this.values,
    this.cellSize = 52.0,
  });

  final String title;
  final List<String> rowLabels;
  final List<String> columnLabels;
  final List<List<double?>> values;
  final double cellSize;

  static const _lowColor = Colors.white;
  static const _highColor = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: title,
      child: rowLabels.isEmpty
          ? _EmptyState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGrid(),
                const SizedBox(height: 12),
                _buildLegend(),
              ],
            ),
    );
  }

  Widget _buildGrid() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column headers.
          Row(
            children: [
              const SizedBox(width: 130), // row label space.
              ...columnLabels.map((c) => SizedBox(
                    width: cellSize,
                    child: Center(
                      child: Text(c,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.kTextSecondary)),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 4),
          // Rows.
          ...List.generate(rowLabels.length, (r) {
            final rowVals = r < values.length ? values[r] : [];
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      rowLabels[r],
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.kTextPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...List.generate(columnLabels.length, (c) {
                    final val =
                        c < rowVals.length ? rowVals[c] : null;
                    return _HeatCell(
                        value: val, size: cellSize);
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('0%',
            style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.kTextSecondary)),
        const SizedBox(width: 6),
        Container(
          width: 80,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
                colors: [_lowColor, _highColor]),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
        ),
        const SizedBox(width: 6),
        Text('100%',
            style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.kTextSecondary)),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.value, required this.size});
  final double? value;
  final double size;

  static const _low = Colors.white;
  static const _high = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Container(
        width: size,
        height: size - 8,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text('—',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF9CA3AF))),
        ),
      );
    }

    final t = (value! / 100).clamp(0.0, 1.0);
    final bg = Color.lerp(_low, _high, t)!;
    final fg = t > 0.5 ? Colors.white : AppColors.kTextPrimary;

    return Container(
      width: size,
      height: size - 8,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Center(
        child: Text(
          '${value!.toStringAsFixed(0)}%',
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    this.legend,
  });

  final String title;
  final Widget child;
  final Widget? legend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.kTextPrimary)),
              ),
              if (legend != null) legend!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart_rounded,
              size: 36, color: AppColors.kTextSecondary),
          const SizedBox(height: 8),
          Text('No data available yet',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.kTextSecondary)),
        ],
      ),
    );
  }
}
