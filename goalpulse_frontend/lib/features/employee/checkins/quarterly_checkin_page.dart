import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/progress_calculator.dart';
import '../../../models/goal_model.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/toast_notification.dart';
import '../goals/goals_provider.dart';
import 'checkin_provider.dart';

/// Employee quarterly check-in page — log actuals and see progress scores.
class QuarterlyCheckinPage extends ConsumerStatefulWidget {
  const QuarterlyCheckinPage({super.key});

  @override
  ConsumerState<QuarterlyCheckinPage> createState() =>
      _QuarterlyCheckinPageState();
}

class _QuarterlyCheckinPageState extends ConsumerState<QuarterlyCheckinPage> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _activeQuarter = 'Q1';
  bool _alreadySubmitted = false;
  GoalSheet? _sheet;

  /// Mutable actuals: goalItemId → {actual, status, score}
  final Map<String, _ActualEntry> _actuals = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  Future<void> _loadData() async {
    await ref.read(goalSheetProvider.notifier).fetchGoalSheet();
    final sheetAsync = ref.read(goalSheetProvider);
    _sheet = sheetAsync.valueOrNull;

    if (_sheet != null) {
      // Initialise actuals from any existing quarterlyData.
      for (final g in _sheet!.goals) {
        final qd = g.quarterlyData[_activeQuarter];
        _actuals[g.goalItemId] = _ActualEntry(
          actual: qd != null ? qd['actual'] : null,
          status: qd != null ? (qd['status'] as String? ?? 'not_started') : 'not_started',
          score: qd != null ? ((qd['progress_score'] as num?)?.toDouble() ?? 0) : 0,
        );
      }

      // Check if already submitted.
      final checkins = await ref.read(
          checkinsByGoalProvider(_sheet!.id).future);
      _alreadySubmitted = checkins.any((c) => c.quarter == _activeQuarter);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _updateActual(GoalItem goal, dynamic actualValue) {
    final score = calculateProgressScore(goal.uomType, goal.target, actualValue);
    setState(() {
      _actuals[goal.goalItemId] = _ActualEntry(
        actual: actualValue,
        status: _actuals[goal.goalItemId]?.status ?? 'not_started',
        score: score,
      );
    });
  }

  void _updateStatus(String goalItemId, String status) {
    setState(() {
      final e = _actuals[goalItemId];
      if (e != null) {
        _actuals[goalItemId] = _ActualEntry(
          actual: e.actual,
          status: status,
          score: e.score,
        );
      }
    });
  }

  double get _overallScore {
    if (_sheet == null) return 0;
    double totalWeight = 0;
    double weightedSum = 0;
    for (final g in _sheet!.goals) {
      final e = _actuals[g.goalItemId];
      if (e != null && e.actual != null) {
        totalWeight += g.weightage;
        weightedSum += (e.score * g.weightage);
      }
    }
    return totalWeight > 0 ? weightedSum / totalWeight : 0;
  }

  Future<void> _submit() async {
    if (_sheet == null) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Submit $_activeQuarter Check-In',
      message: 'Your actuals will be submitted for manager review.',
      confirmLabel: 'Submit',
    );
    if (!confirmed) return;

    setState(() => _isSubmitting = true);

    try {
      final actuals = _sheet!.goals.map((g) {
        final e = _actuals[g.goalItemId];
        return {
          'goal_item_id': g.goalItemId,
          'actual_achievement': e?.actual ?? 0,
          'status': e?.status ?? 'not_started',
        };
      }).toList();

      await ref.read(checkinActionsProvider).submitCheckin(
            goalId: _sheet!.id,
            quarter: _activeQuarter,
            actuals: actuals,
          );

      if (mounted) {
        ToastNotification.showSuccess(
            context, '$_activeQuarter check-in submitted!');
        setState(() => _alreadySubmitted = true);
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.showError(
            context, 'Submission failed: $e');
      }
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = _sheet != null &&
        (_sheet!.sheetStatus == 'approved' || _sheet!.sheetStatus == 'locked');

    return AppShell(
      pageTitle: '$_activeQuarter Check-In',
      role: UserRole.employee,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !isApproved
              ? const EmptyStateWidget(
                  title: 'Goals Not Yet Approved',
                  subtitle:
                      'Your manager needs to approve your goal sheet before you can log actuals.',
                  icon: Icons.lock_outlined,
                )
              : Column(
                  children: [
                    // ── Quarter tabs ──────────────────────────────────
                    Container(
                      padding:
                          const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Row(
                        children: ['Q1', 'Q2', 'Q3', 'Q4'].map((q) {
                          final isActive = q == _activeQuarter;
                          final isOpen = q == 'Q1'; // Hardcoded for demo.
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Tooltip(
                              message: isOpen ? q : '$q — Not yet open',
                              child: ChoiceChip(
                                label: Text(q),
                                selected: isActive,
                                onSelected: isOpen
                                    ? (_) => setState(() {
                                          _activeQuarter = q;
                                        })
                                    : null,
                                selectedColor: AppColors.kBrandPrimary,
                                labelStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? Colors.white
                                      : isOpen
                                          ? AppColors.kTextPrimary
                                          : AppColors.kTextSecondary,
                                ),
                                disabledColor: AppColors.kNeutral100,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // ── Active window banner ─────────────────────────
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.kSuccess.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.kSuccess.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available_rounded,
                              color: AppColors.kSuccess, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '$_activeQuarter Check-in window is open. Deadline: July 31, 2025',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.kSuccess),
                          ),
                        ],
                      ),
                    ),

                    if (_alreadySubmitted)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.kInfo.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.kInfo.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.kInfo, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You have already submitted $_activeQuarter actuals.',
                                style: GoogleFonts.inter(
                                    fontSize: 13, color: AppColors.kInfo),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Scrollable content ───────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildGoalsTable(),
                            const SizedBox(height: 20),
                            _buildOverallCard(),
                            const SizedBox(height: 16),
                            if (!_alreadySubmitted)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isSubmitting ? null : _submit,
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                      : const Icon(Icons.send_rounded,
                                          size: 16),
                                  label: Text(
                                      'Submit $_activeQuarter Actuals'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppColors.kBrandPrimary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            if (_alreadySubmitted) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text(
                                          '✨ AI Summary generation coming in Phase 10'),
                                    ));
                                  },
                                  icon: const Icon(Icons.auto_awesome,
                                      size: 16),
                                  label:
                                      const Text('Generate AI Summary'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        AppColors.kBrandSecondary,
                                    side: BorderSide(
                                      color: AppColors.kBrandSecondary
                                          .withValues(alpha: 0.4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildGoalsTable() {
    final goals = _sheet?.goals ?? [];
    return Container(
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
          rows: goals.map((g) {
            final e = _actuals[g.goalItemId];
            final score = e?.score ?? 0;
            final isReadOnly = _alreadySubmitted || g.isShared;

            return DataRow(cells: [
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(g.title,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (g.isShared) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.kInfo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('Shared',
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.kInfo)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              DataCell(Text(_uomLabel(g.uomType))),
              DataCell(Text('${g.target}')),
              // Actual field.
              DataCell(
                isReadOnly
                    ? Text(g.isShared
                        ? 'Synced'
                        : '${e?.actual ?? '—'}')
                    : SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: e?.actual?.toString() ?? '',
                          keyboardType: g.uomType == 'timeline'
                              ? TextInputType.text
                              : const TextInputType.numberWithOptions(
                                  decimal: true),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          onChanged: (val) {
                            final parsed = double.tryParse(val);
                            _updateActual(g, parsed ?? val);
                          },
                        ),
                      ),
              ),
              // Status dropdown.
              DataCell(
                isReadOnly
                    ? _statusChip(e?.status ?? 'not_started')
                    : DropdownButton<String>(
                        value: e?.status ?? 'not_started',
                        underline: const SizedBox(),
                        isDense: true,
                        style: GoogleFonts.inter(fontSize: 12),
                        items: const [
                          DropdownMenuItem(
                              value: 'not_started',
                              child: Text('Not Started')),
                          DropdownMenuItem(
                              value: 'on_track',
                              child: Text('On Track')),
                          DropdownMenuItem(
                              value: 'completed',
                              child: Text('Completed')),
                        ],
                        onChanged: (val) {
                          if (val != null) _updateStatus(g.goalItemId, val);
                        },
                      ),
              ),
              // Progress score.
              DataCell(_scoreWidget(score)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _scoreWidget(double score) {
    final color = score >= 80
        ? AppColors.kSuccess
        : score >= 50
            ? AppColors.kWarning
            : AppColors.kDanger;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 3,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${score.toStringAsFixed(0)}%',
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
      ],
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

  Widget _buildOverallCard() {
    final score = _overallScore;
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
                Text(
                  '${score.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overall Progress',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kTextPrimary)),
              const SizedBox(height: 4),
              Text('Weighted average across all goals',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.kTextSecondary)),
            ],
          ),
        ],
      ),
    );
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

class _ActualEntry {
  _ActualEntry({this.actual, this.status = 'not_started', this.score = 0});
  final dynamic actual;
  final String status;
  final double score;
}
