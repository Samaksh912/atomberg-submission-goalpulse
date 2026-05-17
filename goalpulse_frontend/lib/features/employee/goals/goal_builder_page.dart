import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/toast_notification.dart';
import 'goals_provider.dart';
import 'widgets/goal_card_widget.dart';
import 'widgets/weightage_meter_widget.dart';
import '../../../features/manager/shared_goals/shared_goals_provider.dart';

/// Interactive goal builder where employees create / edit their goal sheet.
class GoalBuilderPage extends ConsumerStatefulWidget {
  const GoalBuilderPage({super.key});

  @override
  ConsumerState<GoalBuilderPage> createState() => _GoalBuilderPageState();
}

class _GoalBuilderPageState extends ConsumerState<GoalBuilderPage> {
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  Future<void> _loadData() async {
    await ref.read(goalSheetProvider.notifier).fetchGoalSheet();
    if (mounted) setState(() => _isLoading = false);

    // If no goals exist yet, seed one blank draft.
    final drafts = ref.read(localDraftGoalsProvider);
    if (drafts.isEmpty) {
      ref.read(localDraftGoalsProvider.notifier).state = [GoalItemDraft()];
    }
  }

  void _addGoal() {
    final drafts = ref.read(localDraftGoalsProvider);
    if (drafts.length >= 8) return;
    ref.read(localDraftGoalsProvider.notifier).state = [
      ...drafts,
      GoalItemDraft(),
    ];
  }

  void _removeGoal(int index) {
    final drafts = List<GoalItemDraft>.from(ref.read(localDraftGoalsProvider));
    if (drafts.length <= 1) return; // keep at least 1
    drafts.removeAt(index);
    ref.read(localDraftGoalsProvider.notifier).state = drafts;
  }

  void _updateGoal(int index, GoalItemDraft updated) {
    final drafts = List<GoalItemDraft>.from(ref.read(localDraftGoalsProvider));
    drafts[index] = updated;
    ref.read(localDraftGoalsProvider.notifier).state = drafts;
  }

  Future<void> _saveDraft() async {
    setState(() => _isSaving = true);
    final error =
        await ref.read(goalSheetProvider.notifier).createOrUpdateGoals();
    setState(() => _isSaving = false);
    if (!mounted) return;
    if (error == null) {
      ToastNotification.showSuccess(context, 'Goal sheet saved as draft.');
    } else {
      ToastNotification.showError(context, 'Save failed: $error');
    }
  }

  Future<void> _submitSheet() async {
    final validation = ref.read(weightageValidationProvider);
    if (!validation.isValid || validation.hasUnderMinimum) {
      ToastNotification.showError(
          context, 'Fix validation errors before submitting.');
      return;
    }

    // Save first.
    setState(() => _isSaving = true);
    final saveErr =
        await ref.read(goalSheetProvider.notifier).createOrUpdateGoals();
    if (saveErr != null) {
      setState(() => _isSaving = false);
      if (mounted) ToastNotification.showError(context, 'Save failed: $saveErr');
      return;
    }

    if (!mounted) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Submit Goal Sheet',
      message:
          'Once submitted, editing is disabled until your manager reviews it.',
      confirmLabel: 'Submit',
    );
    if (!confirmed) {
      setState(() => _isSaving = false);
      return;
    }

    final submitErr =
        await ref.read(goalSheetProvider.notifier).submitForApproval();
    setState(() => _isSaving = false);
    if (!mounted) return;
    if (submitErr == null) {
      ToastNotification.showSuccess(
          context, 'Goal sheet submitted for approval!');
      context.go('/employee/goals/view');
    } else {
      ToastNotification.showError(context, 'Submit failed: $submitErr');
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts = ref.watch(localDraftGoalsProvider);
    final validation = ref.watch(weightageValidationProvider);
    final sheetAsync = ref.watch(goalSheetProvider);
    final sheet = sheetAsync.valueOrNull;
    final isReturned = sheet?.sheetStatus == 'returned';
    final isSubmitted = sheet?.sheetStatus == 'submitted';
    final isApproved = sheet?.sheetStatus == 'approved' ||
        sheet?.sheetStatus == 'locked';
    final canEdit = sheet == null ||
        sheet.sheetStatus == 'draft' ||
        sheet.sheetStatus == 'returned';
    final canSubmit = validation.isValid &&
        !validation.hasUnderMinimum &&
        !validation.isOverLimit &&
        drafts.every((d) => d.isValid);

    // Redirect to view page if approved/locked.
    if (isApproved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/employee/goals/view');
      });
    }

    return AppShell(
      pageTitle: 'My Goals',
      role: UserRole.employee,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Returned banner ────────────────────────────────
                if (isReturned && sheet?.managerComment != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.kWarning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.kWarning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.feedback_outlined,
                            color: AppColors.kWarning, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Manager Feedback',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.kWarning)),
                              const SizedBox(height: 4),
                              Text(sheet!.managerComment!,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.kTextPrimary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Submitted banner ───────────────────────────────
                if (isSubmitted)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.kInfo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.kInfo.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded,
                            color: AppColors.kInfo, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your goal sheet has been submitted and is awaiting manager approval.',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.kInfo),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Sticky header ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'My Goal Sheet — FY 2025',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.kTextPrimary,
                          ),
                        ),
                      ),

                      // Goal count chip.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: drafts.length >= 8
                              ? AppColors.kWarning.withValues(alpha: 0.15)
                              : AppColors.kNeutral100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${drafts.length} / 8 Goals',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: drafts.length >= 8
                                ? AppColors.kWarning
                                : AppColors.kTextSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Save Draft button.
                      if (canEdit)
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _saveDraft,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.save_outlined, size: 16),
                          label: const Text('Save Draft'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.kBrandPrimary,
                            side: const BorderSide(
                                color: AppColors.kBrandPrimary),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      const SizedBox(width: 8),

                      // Submit button.
                      if (canEdit)
                        Tooltip(
                          message: canSubmit
                              ? 'Submit for approval'
                              : 'Fix validation errors to submit',
                          child: ElevatedButton.icon(
                            onPressed:
                                (canSubmit && !_isSaving) ? _submitSheet : null,
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Submit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.kBrandPrimary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.kBorder,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Scrollable content ─────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                    child: Column(
                      children: [
                        // Weightage meter.
                        const WeightageMeterWidget(),
                        const SizedBox(height: 16),

                        // Goal cards.
                        ...List.generate(drafts.length, (i) {
                          return GoalCardWidget(
                            key: ValueKey('goal_$i'),
                            index: i,
                            draft: drafts[i],
                            isReadOnly: !canEdit,
                            onChanged: (updated) => _updateGoal(i, updated),
                            onDelete: () => _removeGoal(i),
                            onSharedWeightageChanged: (sharedGoalId, w) {
                              // Fire-and-forget weightage persist for shared goals.
                              ref
                                  .read(sharedGoalActionsProvider)
                                  .updateWeightage(sharedGoalId, w)
                                  .catchError((_) {});
                            },
                          );
                        }),

                        // Add Goal button.
                        if (canEdit && drafts.length < 8)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _addGoal,
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: const Text('Add Goal'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.kBrandPrimary,
                                  side: BorderSide(
                                    color: AppColors.kBrandPrimary
                                        .withValues(alpha: 0.4),
                                    style: BorderStyle.solid,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
