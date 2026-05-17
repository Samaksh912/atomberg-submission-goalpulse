import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../models/checkin_model.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/toast_notification.dart';
import '../../employee/checkins/checkin_provider.dart';

/// Manager check-in detail — view actuals comparison and add review comment.
class CheckinDetailPage extends ConsumerStatefulWidget {
  const CheckinDetailPage({super.key, required this.checkinId});

  final String checkinId;

  @override
  ConsumerState<CheckinDetailPage> createState() => _CheckinDetailPageState();
}

class _CheckinDetailPageState extends ConsumerState<CheckinDetailPage> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  CheckinRecord? _checkin;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCheckin);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCheckin() async {
    // We need to fetch the checkin by finding it. The API currently only lists by goalId,
    // so we'll do a direct Firestore-style fetch through the goal's checkins.
    // For now, use a generic approach: try to fetch from the API by constructing the path.
    try {
      final auth = ref.read(authServiceProvider);
      final token = await auth.getCurrentIdToken();
      if (token == null) return;

      // The checkin_id can be used to fetch directly — we'll add a simple helper.
      // For now, we iterate team goals to find the right checkin.
      final api = ref.read(apiClientProvider);

      // Get team goals and find checkins.
      final teamRes = await api.get(
        '/goals/team',
        options: ApiClient.bearerOptions(token),
      );
      final sheets = teamRes.data as List<dynamic>? ?? [];

      for (final s in sheets) {
        final goalId = s['id'] as String? ?? '';
        if (goalId.isEmpty) continue;

        final checkinsRes = await api.get(
          '/checkins/$goalId',
          options: ApiClient.bearerOptions(token),
        );
        final checkins = checkinsRes.data as List<dynamic>? ?? [];
        for (final c in checkins) {
          if (c['id'] == widget.checkinId) {
            _checkin = CheckinRecord.fromJson(c as Map<String, dynamic>);
            break;
          }
        }
        if (_checkin != null) break;
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.showError(context, 'Failed to load check-in.');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _completeReview() async {
    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) {
      ToastNotification.showError(
          context, 'Please add a comment before completing the review.');
      return;
    }

    if (!mounted) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Complete Check-In Review',
      message: 'Your comment will be visible to the employee.',
      confirmLabel: 'Complete Review',
    );
    if (!confirmed) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(checkinActionsProvider)
          .managerReview(widget.checkinId, comment);
      if (mounted) {
        ToastNotification.showSuccess(context, 'Check-in reviewed.');
        context.go('/manager/checkins');
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.showError(context, 'Review failed: $e');
      }
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      pageTitle: 'Check-In Review',
      role: UserRole.manager,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _checkin == null
              ? Center(
                  child: Text('Check-in not found.',
                      style: GoogleFonts.inter(
                          fontSize: 16, color: AppColors.kTextSecondary)),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Info header.
                            _buildInfoHeader(),
                            const SizedBox(height: 20),

                            // Overall score.
                            _buildOverallScore(),
                            const SizedBox(height: 20),

                            // Comparison table.
                            Text('Goal Performance',
                                style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.kTextPrimary)),
                            const SizedBox(height: 12),
                            _buildComparisonTable(),
                            const SizedBox(height: 20),

                            // Per-goal bar chart.
                            Text('Progress Scores',
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.kTextPrimary)),
                            const SizedBox(height: 12),
                            _buildBarChart(),
                          ],
                        ),
                      ),
                    ),

                    // Action bar.
                    if (_checkin!.status != 'manager_reviewed')
                      _buildActionBar()
                    else
                      _buildReviewedBar(),
                  ],
                ),
    );
  }

  Widget _buildInfoHeader() {
    final c = _checkin!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
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
            child: Text(c.quarter,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.quarter} Check-In',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.kTextPrimary)),
                if (c.employeeSubmittedAt != null)
                  Text(
                    'Submitted ${_formatDate(c.employeeSubmittedAt!)}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.kTextSecondary),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.status == 'manager_reviewed'
                  ? AppColors.kSuccess.withValues(alpha: 0.1)
                  : AppColors.kWarning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              c.status == 'manager_reviewed'
                  ? 'Reviewed'
                  : 'Pending Review',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.status == 'manager_reviewed'
                    ? AppColors.kSuccess
                    : AppColors.kWarning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallScore() {
    final score = _checkin!.overallScore;
    final color = score >= 80
        ? AppColors.kSuccess
        : score >= 50
            ? AppColors.kWarning
            : AppColors.kDanger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Text('${score.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overall Weighted Score',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kTextPrimary)),
              const SizedBox(height: 4),
              Text('Across ${_checkin!.actuals.length} goals',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.kTextSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    final actuals = _checkin!.actuals;
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
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('Goal Title')),
            DataColumn(label: Text('UoM')),
            DataColumn(label: Text('Target')),
            DataColumn(label: Text('Actual')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Score')),
          ],
          rows: actuals.map((a) {
            final score = a.progressScore;
            final color = score >= 80
                ? AppColors.kSuccess
                : score >= 50
                    ? AppColors.kWarning
                    : AppColors.kDanger;

            return DataRow(
              color: WidgetStateProperty.resolveWith((_) =>
                  score < 50
                      ? AppColors.kDanger.withValues(alpha: 0.04)
                      : null),
              cells: [
                DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(a.goalTitle,
                        overflow: TextOverflow.ellipsis))),
                DataCell(Text(_uomLabel(a.uomType))),
                DataCell(Text('${a.target}')),
                DataCell(Text('${a.actualAchievement}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                DataCell(_statusChip(a.status)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 2.5,
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${score.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ],
                )),
              ],
            );
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

  Widget _buildBarChart() {
    final actuals = _checkin!.actuals;
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
                interval: 25,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}%',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.kTextSecondary),
                ),
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
            final score = a.progressScore;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: score.clamp(0, 100),
                  color: score >= 80
                      ? AppColors.kSuccess
                      : score >= 50
                          ? AppColors.kWarning
                          : AppColors.kDanger,
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        border: Border(
          top: BorderSide(color: AppColors.kBorder.withValues(alpha: 0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _commentCtrl,
              decoration: InputDecoration(
                hintText: 'Add your check-in comment...',
                helperText: 'This comment will be visible to the employee',
                helperStyle: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.kTextSecondary),
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.kTextSecondary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              style: GoogleFonts.inter(fontSize: 13),
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _completeReview,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Complete Review'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kBrandPrimary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewedBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.kSuccess.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(color: AppColors.kSuccess.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              color: AppColors.kSuccess, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Review Complete',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.kSuccess)),
                if (_checkin?.managerComment != null)
                  Text(_checkin!.managerComment!,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.kTextSecondary)),
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
