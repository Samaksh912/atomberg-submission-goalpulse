import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/shared_goal_model.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/loading_skeleton.dart';
import '../../../widgets/toast_notification.dart';
import '../../manager/approvals/approvals_provider.dart';
import 'shared_goals_provider.dart';
import '../../../features/employee/goals/widgets/uom_selector_widget.dart';

/// Manager page to view and push shared KPIs to the team.
class SharedGoalsPage extends ConsumerStatefulWidget {
  const SharedGoalsPage({super.key});

  @override
  ConsumerState<SharedGoalsPage> createState() => _SharedGoalsPageState();
}

class _SharedGoalsPageState extends ConsumerState<SharedGoalsPage> {
  bool _panelOpen = false;

  void _openPanel() => setState(() => _panelOpen = true);
  void _closePanel() => setState(() => _panelOpen = false);

  @override
  Widget build(BuildContext context) {
    final sharedAsync = ref.watch(sharedGoalsProvider);

    return AppShell(
      pageTitle: 'Shared Goals',
      role: UserRole.manager,
      child: Stack(
        children: [
          // Main content.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header bar.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Shared Goals',
                              style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.kTextPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            'Push departmental KPIs directly to your team\'s goal sheets.',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.kTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openPanel,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Push New KPI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kBrandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: sharedAsync.when(
                  loading: () => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: List.generate(
                          3,
                          (_) => const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: LoadingSkeletonCard(),
                              )),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error: $e',
                        style:
                            GoogleFonts.inter(color: AppColors.kDanger)),
                  ),
                  data: (shared) {
                    if (shared.isEmpty) {
                      return const EmptyStateWidget(
                        title: 'No Shared Goals Yet',
                        subtitle:
                            'Push a departmental KPI to your team to get started.',
                        icon: Icons.share_outlined,
                        ctaLabel: 'Push New KPI',
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: shared.length,
                      itemBuilder: (context, i) =>
                          _SharedGoalCard(goal: shared[i]),
                    );
                  },
                ),
              ),
            ],
          ),

          // Slide-over panel overlay.
          if (_panelOpen) ...[
            // Dim backdrop.
            GestureDetector(
              onTap: _closePanel,
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
            // Panel.
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 480,
              child: _PushKpiPanel(
                onClose: _closePanel,
                onSuccess: (count) {
                  _closePanel();
                  ToastNotification.showSuccess(
                    context,
                    'KPI pushed to $count employees. Goal added to their sheets.',
                  );
                  ref.invalidate(sharedGoalsProvider);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared Goal Card ─────────────────────────────────────────────────────

class _SharedGoalCard extends StatelessWidget {
  const _SharedGoalCard({required this.goal});
  final SharedGoal goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.kBrandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  goal.thrustArea,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.kBrandPrimary),
                ),
              ),
              const Spacer(),
              _chip(
                '${goal.recipientCount} Employees',
                AppColors.kInfo,
                Icons.group_outlined,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(goal.title,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.kTextPrimary)),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(goal.description,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.kTextSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _chip(_uomLabel(goal.uomType), AppColors.kTextSecondary, null),
              const SizedBox(width: 8),
              _chip('Target: ${goal.target}', AppColors.kSuccess, null),
              const SizedBox(width: 8),
              _chip(
                  '${goal.suggestedWeightage.toStringAsFixed(0)}% weight',
                  AppColors.kWarning,
                  null),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.sync_rounded,
                  size: 14, color: AppColors.kTextSecondary),
              const SizedBox(width: 6),
              Text(
                'Actuals sync from owner employee',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
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
        'zero' => 'Zero Target',
        _ => uom,
      };
}

// ── Push KPI Panel ───────────────────────────────────────────────────────

class _PushKpiPanel extends ConsumerStatefulWidget {
  const _PushKpiPanel({required this.onClose, required this.onSuccess});
  final VoidCallback onClose;
  final void Function(int count) onSuccess;

  @override
  ConsumerState<_PushKpiPanel> createState() => _PushKpiPanelState();
}

class _PushKpiPanelState extends ConsumerState<_PushKpiPanel> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Form state.
  String _thrustArea = '';
  String _title = '';
  String _description = '';
  String _uomType = '';
  String _target = '';
  double _suggestedWeightage = 20;
  String _ownerEmployeeId = '';
  final Set<String> _selectedRecipients = {};

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamGoalsProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Panel header.
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.kBorder.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                const Icon(Icons.share_outlined,
                    color: AppColors.kBrandPrimary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Push Shared KPI to Team',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.kTextPrimary)),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.kTextSecondary),
                ),
              ],
            ),
          ),

          // Form body.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thrust Area.
                    _label('Thrust Area *'),
                    DropdownButtonFormField<String>(
                      value: _thrustArea.isEmpty ? null : _thrustArea,
                      hint: Text('Select thrust area',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.kTextSecondary)),
                      decoration:
                          _inputDecoration(),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                      items: thrustAreas
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _thrustArea = v ?? ''),
                    ),
                    const SizedBox(height: 14),

                    // Goal Title.
                    _label('Goal Title *'),
                    TextFormField(
                      decoration: _inputDecoration(
                          hint: 'e.g. Increase Revenue by 20%'),
                      style: GoogleFonts.inter(fontSize: 13),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Required'
                          : null,
                      onChanged: (v) => _title = v,
                    ),
                    const SizedBox(height: 14),

                    // Description.
                    _label('Description (optional)'),
                    TextFormField(
                      decoration: _inputDecoration(
                          hint: 'Describe the goal...'),
                      style: GoogleFonts.inter(fontSize: 13),
                      maxLines: 3,
                      onChanged: (v) => _description = v,
                    ),
                    const SizedBox(height: 14),

                    // UoM.
                    _label('Unit of Measure *'),
                    UomSelectorWidget(
                      selected: _uomType,
                      onChanged: (v) =>
                          setState(() => _uomType = v),
                    ),
                    if (_uomType.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 2),
                        child: Text('Required',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.kDanger)),
                      ),
                    const SizedBox(height: 14),

                    // Target.
                    _label('Target *'),
                    TextFormField(
                      decoration:
                          _inputDecoration(hint: _uomType == 'timeline'
                              ? 'YYYY-MM-DD'
                              : 'e.g. 1000000'),
                      style: GoogleFonts.inter(fontSize: 13),
                      keyboardType: _uomType == 'timeline'
                          ? TextInputType.text
                          : const TextInputType.numberWithOptions(
                              decimal: true),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Required'
                          : null,
                      onChanged: (v) => _target = v,
                    ),
                    const SizedBox(height: 14),

                    // Suggested Weightage.
                    _label('Suggested Weightage (%)'),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _suggestedWeightage,
                            min: 10,
                            max: 100,
                            divisions: 18,
                            label:
                                '${_suggestedWeightage.toStringAsFixed(0)}%',
                            activeColor: AppColors.kBrandPrimary,
                            onChanged: (v) => setState(
                                () => _suggestedWeightage = v),
                          ),
                        ),
                        Container(
                          width: 50,
                          alignment: Alignment.center,
                          child: Text(
                            '${_suggestedWeightage.toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.kBrandPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Team member list (recipients + owner).
                    teamAsync.when(
                      loading: () =>
                          const CircularProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                      data: (sheets) {
                        // Build team member list from sheets.
                        final members = sheets
                            .map((s) => _TeamMember(
                                id: s.employeeId,
                                name: s.employeeName.isNotEmpty
                                    ? s.employeeName
                                    : s.employeeEmail,
                                department: s.employeeDepartment))
                            .toList();

                        if (members.isEmpty) {
                          return Text(
                            'No team members found. Seed demo data first.',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.kTextSecondary),
                          );
                        }

                        return Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            // Owner.
                            _label('Goal Owner *'),
                            Text(
                              'Whose actuals will sync to all recipients?',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.kTextSecondary),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _ownerEmployeeId.isEmpty
                                  ? null
                                  : _ownerEmployeeId,
                              hint: Text('Select owner',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color:
                                          AppColors.kTextSecondary)),
                              decoration:
                                  _inputDecoration(),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Required'
                                  : null,
                              items: members
                                  .map((m) => DropdownMenuItem(
                                      value: m.id,
                                      child: Text(m.name)))
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _ownerEmployeeId = v ?? '';
                                  // Auto-add owner to recipients.
                                  if (v != null) {
                                    _selectedRecipients.add(v);
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Recipients multi-select.
                            Row(
                              children: [
                                Expanded(
                                  child: _label('Recipients *'),
                                ),
                                TextButton(
                                  onPressed: () => setState(() =>
                                      _selectedRecipients.addAll(
                                          members.map((m) => m.id))),
                                  child: const Text('All'),
                                ),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _selectedRecipients.clear();
                                    if (_ownerEmployeeId
                                        .isNotEmpty) {
                                      _selectedRecipients.add(
                                          _ownerEmployeeId);
                                    }
                                  }),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppColors.kBorder
                                        .withValues(alpha: 0.5)),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: members.map((m) {
                                  final isOwner =
                                      m.id == _ownerEmployeeId;
                                  final isSelected =
                                      _selectedRecipients
                                          .contains(m.id);
                                  return CheckboxListTile(
                                    value: isSelected,
                                    title: Row(
                                      children: [
                                        Text(m.name,
                                            style:
                                                GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight
                                                            .w500)),
                                        if (isOwner) ...[
                                          const SizedBox(
                                              width: 6),
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 5,
                                                vertical: 1),
                                            decoration:
                                                BoxDecoration(
                                              color: AppColors
                                                  .kBrandPrimary
                                                  .withValues(
                                                      alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(4),
                                            ),
                                            child: Text('Owner',
                                                style:
                                                    GoogleFonts.inter(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight
                                                                .w700,
                                                        color: AppColors
                                                            .kBrandPrimary)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(m.department,
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors
                                                .kTextSecondary)),
                                    activeColor:
                                        AppColors.kBrandPrimary,
                                    dense: true,
                                    onChanged: isOwner
                                        ? null // Owner can't be unchecked.
                                        : (val) => setState(() {
                                              if (val == true) {
                                                _selectedRecipients
                                                    .add(m.id);
                                              } else {
                                                _selectedRecipients
                                                    .remove(m.id);
                                              }
                                            }),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Action buttons.
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: AppColors.kBorder.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onClose,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                        'Push to ${_selectedRecipients.length} Selected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kBrandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uomType.isEmpty) {
      ToastNotification.showError(context, 'Please select a unit of measure.');
      return;
    }
    if (_selectedRecipients.isEmpty) {
      ToastNotification.showError(
          context, 'At least one recipient is required.');
      return;
    }
    if (_ownerEmployeeId.isEmpty) {
      ToastNotification.showError(context, 'Please select a goal owner.');
      return;
    }
    if (!_selectedRecipients.contains(_ownerEmployeeId)) {
      ToastNotification.showError(
          context, 'The owner must be one of the selected recipients.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result =
          await ref.read(sharedGoalActionsProvider).pushSharedGoal({
        'cycle_id': 'cycle_2025',
        'thrust_area': _thrustArea,
        'title': _title.trim(),
        'description': _description.trim(),
        'uom_type': _uomType,
        'target': double.tryParse(_target) ?? _target,
        'suggested_weightage': _suggestedWeightage,
        'recipient_ids': _selectedRecipients.toList(),
        'owner_employee_id': _ownerEmployeeId,
      });
      final count = result?['updatedCount'] as int? ?? _selectedRecipients.length;
      widget.onSuccess(count);
    } catch (e) {
      if (mounted) {
        ToastNotification.showError(
            context, 'Failed to push KPI: $e');
      }
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.kTextPrimary)),
    );
  }

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            fontSize: 13, color: AppColors.kTextSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: AppColors.kBorder.withValues(alpha: 0.6)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      );
}

/// Simple holder for team member info in the form.
class _TeamMember {
  const _TeamMember(
      {required this.id, required this.name, required this.department});
  final String id;
  final String name;
  final String department;
}
