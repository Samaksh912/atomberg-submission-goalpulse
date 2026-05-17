import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../widgets/confirm_dialog.dart';
import '../goals_provider.dart';
import 'uom_selector_widget.dart';

/// Expandable card for a single goal inside the goal builder.
///
/// Shows a compact header when collapsed and a full form when expanded.
class GoalCardWidget extends StatefulWidget {
  const GoalCardWidget({
    super.key,
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onDelete,
    this.isReadOnly = false,
    this.onSharedWeightageChanged,
  });

  final int index;
  final GoalItemDraft draft;
  final ValueChanged<GoalItemDraft> onChanged;
  final VoidCallback onDelete;
  final bool isReadOnly;
  /// Called when a shared goal's weightage is changed, to persist to API.
  final void Function(String sharedGoalId, double weightage)? onSharedWeightageChanged;

  @override
  State<GoalCardWidget> createState() => _GoalCardWidgetState();
}

class _GoalCardWidgetState extends State<GoalCardWidget> {
  bool _expanded = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _targetCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.draft.title);
    _descCtrl = TextEditingController(text: widget.draft.description);
    _targetCtrl = TextEditingController(
      text: widget.draft.target?.toString() ?? '',
    );
    // Auto-expand new empty goals.
    if (widget.draft.title.isEmpty) {
      _expanded = true;
    }
  }

  @override
  void didUpdateWidget(GoalCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.title != widget.draft.title &&
        widget.draft.title != _titleCtrl.text) {
      _titleCtrl.text = widget.draft.title;
    }
    if (oldWidget.draft.description != widget.draft.description &&
        widget.draft.description != _descCtrl.text) {
      _descCtrl.text = widget.draft.description;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  void _emit(GoalItemDraft updated) => widget.onChanged(updated);

  // ── Colours for the numbered circle ───────────────────────────────────
  static const _palette = [
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final color = _palette[widget.index % _palette.length];
    final isValid = d.isValid;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded
              ? color.withValues(alpha: 0.4)
              : AppColors.kBorder.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── HEADER ─────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Number circle.
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('${widget.index + 1}',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                  const SizedBox(width: 12),

                  // Title.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.title.isNotEmpty ? d.title : 'New Goal',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: d.title.isNotEmpty
                                ? AppColors.kTextPrimary
                                : AppColors.kTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (d.thrustArea.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(d.thrustArea,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.kTextSecondary)),
                        ],
                      ],
                    ),
                  ),

                  // Shared badge.
                  if (d.isShared) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.kInfo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Shared',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.kInfo)),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Weightage chip.
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: d.weightage < 10
                          ? AppColors.kDanger.withValues(alpha: 0.1)
                          : AppColors.kBrandPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${d.weightage.toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: d.weightage < 10
                            ? AppColors.kDanger
                            : AppColors.kBrandPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Status icon.
                  Icon(
                    isValid
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 20,
                    color: isValid ? AppColors.kSuccess : AppColors.kWarning,
                  ),
                  const SizedBox(width: 4),

                  // Delete button.
                  if (!widget.isReadOnly)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.kDanger),
                      onPressed: () async {
                        final confirmed = await ConfirmDialog.show(
                          context,
                          title: 'Delete Goal',
                          message:
                              'Remove "${d.title.isNotEmpty ? d.title : 'Goal ${widget.index + 1}'}" from your goal sheet?',
                          confirmLabel: 'Delete',
                          isDanger: true,
                        );
                        if (confirmed) widget.onDelete();
                      },
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                      tooltip: 'Delete goal',
                    ),

                  // Chevron.
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more,
                        color: AppColors.kTextSecondary),
                  ),
                ],
              ),
            ),
          ),

          // ── EXPANDED FORM ──────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildForm(context),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final d = widget.draft;
    final readOnly = widget.isReadOnly || d.isShared;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Shared goal info.
          if (d.isShared)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.kInfo.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.kInfo.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.kInfo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This goal was shared by your manager. Only weightage can be adjusted.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.kInfo),
                    ),
                  ),
                ],
              ),
            ),

          // ── Thrust Area ───────────────────────────────────────────
          DropdownButtonFormField<String>(
            initialValue:
                d.thrustArea.isNotEmpty ? d.thrustArea : null,
            decoration: _inputDecoration('Thrust Area'),
            items: thrustAreas
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: readOnly
                ? null
                : (val) {
                    if (val != null) {
                      _emit(d.copyWith(thrustArea: val));
                    }
                  },
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.kTextPrimary),
          ),
          const SizedBox(height: 14),

          // ── Title ─────────────────────────────────────────────────
          TextFormField(
            controller: _titleCtrl,
            readOnly: readOnly,
            maxLength: 100,
            decoration: _inputDecoration('Goal Title').copyWith(
              counterText: '${_titleCtrl.text.length}/100',
            ),
            style: GoogleFonts.inter(fontSize: 14),
            onChanged: (val) => _emit(d.copyWith(title: val)),
          ),
          const SizedBox(height: 14),

          // ── Description ───────────────────────────────────────────
          TextFormField(
            controller: _descCtrl,
            readOnly: readOnly,
            maxLength: 500,
            maxLines: 3,
            decoration: _inputDecoration('Description (optional)').copyWith(
              counterText: '${_descCtrl.text.length}/500',
            ),
            style: GoogleFonts.inter(fontSize: 14),
            onChanged: (val) => _emit(d.copyWith(description: val)),
          ),
          const SizedBox(height: 14),

          // ── UoM Selector ──────────────────────────────────────────
          UomSelectorWidget(
            selected: d.uomType,
            onChanged: readOnly
                ? (_) {}
                : (val) => _emit(d.copyWith(uomType: val)),
          ),
          const SizedBox(height: 14),

          // ── Target ────────────────────────────────────────────────
          if (d.uomType == 'zero')
            TextFormField(
              readOnly: true,
              initialValue: '0 = Success',
              decoration: _inputDecoration('Target'),
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.kTextSecondary),
            )
          else if (d.uomType == 'timeline')
            InkWell(
              onTap: readOnly
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        final iso =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        _targetCtrl.text = iso;
                        _emit(d.copyWith(target: iso));
                      }
                    },
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _targetCtrl,
                  readOnly: true,
                  decoration: _inputDecoration('Target Date')
                      .copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 18)),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
            )
          else
            TextFormField(
              controller: _targetCtrl,
              readOnly: readOnly,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: _inputDecoration(
                d.uomType.contains('percent')
                    ? 'Target (%)'
                    : 'Target (Numeric)',
              ),
              style: GoogleFonts.inter(fontSize: 14),
              onChanged: (val) {
                final parsed = double.tryParse(val);
                if (parsed != null) _emit(d.copyWith(target: parsed));
              },
            ),
          const SizedBox(height: 16),

          // ── Weightage slider ──────────────────────────────────────
          Text('Weightage',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.kTextSecondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.kBrandPrimary,
                    inactiveTrackColor:
                        AppColors.kBrandPrimary.withValues(alpha: 0.15),
                    thumbColor: AppColors.kBrandPrimary,
                    overlayColor:
                        AppColors.kBrandPrimary.withValues(alpha: 0.12),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: d.weightage.clamp(10, 100),
                    min: 10,
                    max: 100,
                    divisions: 18,
                    label: '${d.weightage.toStringAsFixed(0)}%',
                    onChanged: (widget.isReadOnly && !d.isShared)
                        ? null
                        : (val) {
                            final rounded = (val / 5).round() * 5.0;
                            _emit(d.copyWith(weightage: rounded));
                            if (d.isShared && d.sharedGoalId != null) {
                              widget.onSharedWeightageChanged
                                  ?.call(d.sharedGoalId!, rounded);
                            }
                          },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: TextFormField(
                  key: ValueKey('wt_${d.weightage}'),
                  initialValue: d.weightage.toStringAsFixed(0),
                  readOnly: widget.isReadOnly,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    suffixText: '%',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  onChanged: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null && parsed >= 10 && parsed <= 100) {
                      _emit(d.copyWith(weightage: parsed));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── AI Suggest button ─────────────────────────────────────
          if (!widget.isReadOnly)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✨ AI Suggestions coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('AI Suggest'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.kBrandSecondary,
                  side: BorderSide(
                      color: AppColors.kBrandSecondary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(fontSize: 13, color: AppColors.kTextSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.kBorder.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.kBrandPrimary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}
