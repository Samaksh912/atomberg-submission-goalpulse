import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../models/goal_model.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/toast_notification.dart';
import '../../employee/goals/goals_provider.dart';
import '../../employee/goals/widgets/weightage_meter_widget.dart';
import 'approvals_provider.dart';

/// Manager review page for a submitted goal sheet.
///
/// Allows inline editing of target and weightage values,
/// then approving or returning the sheet.
class GoalReviewPage extends ConsumerStatefulWidget {
  const GoalReviewPage({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<GoalReviewPage> createState() => _GoalReviewPageState();
}

class _GoalReviewPageState extends ConsumerState<GoalReviewPage> {
  bool _isLoading = true;
  bool _isActing = false;
  GoalSheetSummary? _sheet;
  late List<GoalItemDraft> _editedGoals;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _editedGoals = [];
    Future.microtask(_loadGoalSheet);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGoalSheet() async {
    // Try from selectedGoalProvider first.
    final selected = ref.read(selectedGoalProvider);
    if (selected != null && selected.id == widget.goalId) {
      _sheet = selected;
      _syncDrafts(selected.goals);
      setState(() => _isLoading = false);
      return;
    }

    // Fallback: fetch from API.
    try {
      final auth = ref.read(authServiceProvider);
      final token = await auth.getCurrentIdToken();
      if (token == null) return;

      final api = ref.read(apiClientProvider);
      final res = await api.get(
        '/goals/${widget.goalId}',
        options: ApiClient.bearerOptions(token),
      );
      if (res.data != null) {
        final json = res.data as Map<String, dynamic>;
        _sheet = GoalSheetSummary.fromJson(json);
        _syncDrafts(_sheet!.goals);
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.showError(context, 'Failed to load goal sheet.');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _syncDrafts(List<GoalItem> goals) {
    _editedGoals = goals
        .map((g) => GoalItemDraft(
              thrustArea: g.thrustArea,
              title: g.title,
              description: g.description,
              uomType: g.uomType,
              target: g.target,
              weightage: g.weightage,
              isShared: g.isShared,
              sharedGoalId: g.sharedGoalId,
            ))
        .toList();
    // Sync to local provider for the weightage meter.
    ref.read(localDraftGoalsProvider.notifier).state = _editedGoals;
  }

  Future<void> _approve() async {
    final validation = ref.read(weightageValidationProvider);
    if (!validation.isValid || validation.hasUnderMinimum) {
      ToastNotification.showError(
          context, 'Fix weightage validation errors before approving.');
      return;
    }

    if (!mounted) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Approve Goal Sheet',
      message:
          'This will lock all goals. The employee cannot edit after approval.',
      confirmLabel: 'Approve',
    );
    if (!confirmed) return;

    setState(() => _isActing = true);

    // Build edited goals list.
    final edits = <Map<String, dynamic>>[];
    if (_sheet != null) {
      for (var i = 0; i < _editedGoals.length; i++) {
        if (i < _sheet!.goals.length) {
          final original = _sheet!.goals[i];
          final edited = _editedGoals[i];
          if (original.target != edited.target ||
              original.weightage != edited.weightage) {
            edits.add({
              'goalItemId': original.goalItemId,
              'target': edited.target,
              'weightage': edited.weightage,
            });
          }
        }
      }
    }

    final comment = _commentCtrl.text.trim().isNotEmpty
        ? _commentCtrl.text.trim()
        : null;
    final err = await ref.read(managerGoalActionsProvider).approveGoalSheet(
          widget.goalId,
          comment: comment,
          editedGoals: edits.isNotEmpty ? edits : null,
        );

    setState(() => _isActing = false);
    if (!mounted) return;

    if (err == null) {
      ToastNotification.showSuccess(
          context, 'Goal sheet approved and locked.');
      context.go('/manager/approvals');
    } else {
      ToastNotification.showError(context, 'Approval failed: $err');
    }
  }

  Future<void> _returnSheet() async {
    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) {
      ToastNotification.showError(
          context, 'A comment is required when returning a goal sheet.');
      return;
    }

    if (!mounted) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Return for Rework',
      message:
          'The employee will be notified and can re-edit their goals.',
      confirmLabel: 'Return',
      isDanger: true,
    );
    if (!confirmed) return;

    setState(() => _isActing = true);
    final err = await ref
        .read(managerGoalActionsProvider)
        .returnGoalSheet(widget.goalId, comment);

    setState(() => _isActing = false);
    if (!mounted) return;

    if (err == null) {
      ToastNotification.showSuccess(
          context, 'Goal sheet returned with feedback.');
      context.go('/manager/approvals');
    } else {
      ToastNotification.showError(context, 'Return failed: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final validation = ref.watch(weightageValidationProvider);

    return AppShell(
      pageTitle: 'Review Goal Sheet',
      role: UserRole.manager,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sheet == null
              ? Center(
                  child: Text('Goal sheet not found.',
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
                            // ── Employee info card ───────────────────
                            _buildEmployeeCard(),
                            const SizedBox(height: 20),

                            // ── Goals table ─────────────────────────
                            Text('Goals',
                                style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.kTextPrimary)),
                            const SizedBox(height: 12),
                            _buildGoalsTable(),
                            const SizedBox(height: 16),

                            // ── Weightage meter ─────────────────────
                            const WeightageMeterWidget(),
                          ],
                        ),
                      ),
                    ),

                    // ── Action bar ──────────────────────────────────
                    _buildActionBar(validation),
                  ],
                ),
    );
  }

  Widget _buildEmployeeCard() {
    final s = _sheet!;
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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.kBrandPrimary, AppColors.kBrandSecondary],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(s.employeeName),
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.employeeName.isNotEmpty ? s.employeeName : s.employeeEmail,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kTextPrimary),
                ),
                if (s.employeeDepartment.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(s.employeeDepartment,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.kTextSecondary)),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 13, color: AppColors.kTextSecondary),
                    const SizedBox(width: 4),
                    Text(
                      s.submittedAt != null
                          ? 'Submitted ${_formatDate(s.submittedAt!)}'
                          : 'Submitted',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.kTextSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _chip('${s.goalCount} Goals', AppColors.kBrandPrimary),
                  const SizedBox(width: 6),
                  _chip(
                    '${s.totalWeightage.toStringAsFixed(0)}%',
                    s.totalWeightage == 100
                        ? AppColors.kSuccess
                        : AppColors.kWarning,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsTable() {
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
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Thrust Area')),
            DataColumn(label: Text('Goal Title')),
            DataColumn(label: Text('UoM')),
            DataColumn(label: Text('Target')),
            DataColumn(label: Text('Weightage')),
            DataColumn(label: Text('')),
          ],
          rows: List.generate(_editedGoals.length, (i) {
            final d = _editedGoals[i];
            final original = _sheet!.goals[i];
            final targetChanged = d.target != original.target;
            final weightageChanged = d.weightage != original.weightage;

            return DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(d.thrustArea)),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(d.title, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(Text(_uomLabel(d.uomType))),
              // Editable target.
              DataCell(
                _EditableCell(
                  value: '${d.target ?? ''}',
                  isEdited: targetChanged,
                  keyboardType: d.uomType.contains('timeline')
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    setState(() {
                      final parsed = double.tryParse(val);
                      _editedGoals[i] = d.copyWith(
                          target: parsed ?? val);
                      ref.read(localDraftGoalsProvider.notifier).state =
                          List.from(_editedGoals);
                    });
                  },
                ),
              ),
              // Editable weightage.
              DataCell(
                _EditableCell(
                  value: d.weightage.toStringAsFixed(0),
                  isEdited: weightageChanged,
                  suffix: '%',
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null) {
                      setState(() {
                        _editedGoals[i] =
                            d.copyWith(weightage: parsed);
                        ref.read(localDraftGoalsProvider.notifier).state =
                            List.from(_editedGoals);
                      });
                    }
                  },
                ),
              ),
              // Shared badge.
              DataCell(
                d.isShared
                    ? Container(
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
                      )
                    : const SizedBox.shrink(),
              ),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _buildActionBar(WeightageValidation validation) {
    final canApprove =
        validation.isValid && !validation.hasUnderMinimum && !_isActing;

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
          // Comment field.
          Expanded(
            child: TextFormField(
              controller: _commentCtrl,
              decoration: InputDecoration(
                hintText:
                    'Add a comment (optional for approval, required for return)',
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.kTextSecondary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: AppColors.kBorder.withValues(alpha: 0.6)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),

          // Return button.
          OutlinedButton.icon(
            onPressed: _isActing ? null : _returnSheet,
            icon: const Icon(Icons.undo_rounded, size: 16),
            label: const Text('Return for Rework'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.kDanger,
              side: const BorderSide(color: AppColors.kDanger),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 10),

          // Approve button.
          Tooltip(
            message: canApprove
                ? 'Approve and lock goals'
                : 'Fix validation errors to approve',
            child: ElevatedButton.icon(
              onPressed: canApprove ? _approve : null,
              icon: _isActing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Approve Goal Sheet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kSuccess,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.kBorder,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
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

// ── Inline editable cell widget ──────────────────────────────────────────

class _EditableCell extends StatefulWidget {
  const _EditableCell({
    required this.value,
    required this.onChanged,
    this.isEdited = false,
    this.suffix,
    this.keyboardType,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool isEdited;
  final String? suffix;
  final TextInputType? keyboardType;

  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_EditableCell old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_editing) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _finishEdit() {
    setState(() => _editing = false);
    widget.onChanged(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return SizedBox(
        width: 80,
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: widget.keyboardType,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            suffixText: widget.suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                  color: AppColors.kBrandPrimary, width: 1.5),
            ),
          ),
          onFieldSubmitted: (_) => _finishEdit(),
          onTapOutside: (_) => _finishEdit(),
        ),
      );
    }

    return InkWell(
      onTap: () => setState(() => _editing = true),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.isEdited
              ? AppColors.kWarning.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.isEdited
                ? AppColors.kWarning.withValues(alpha: 0.4)
                : AppColors.kBorder.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.value}${widget.suffix ?? ''}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isEdited
                    ? AppColors.kWarning
                    : AppColors.kTextPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined,
                size: 12,
                color: AppColors.kTextSecondary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
