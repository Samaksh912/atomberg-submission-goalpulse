import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/toast_notification.dart';
import '../../../widgets/loading_skeleton.dart';
import '../admin_provider.dart';

class CycleManagementPage extends ConsumerStatefulWidget {
  const CycleManagementPage({super.key});

  @override
  ConsumerState<CycleManagementPage> createState() =>
      _CycleManagementPageState();
}

class _CycleManagementPageState extends ConsumerState<CycleManagementPage> {
  bool _isLoading = true;
  List<Cycle> _cycles = [];
  Cycle? _active;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(adminApiProvider);
      final results = await Future.wait([
        api.getCycles(),
        api.getActiveCycle(),
      ]);
      setState(() {
        _cycles = results[0] as List<Cycle>;
        _active = results[1] as Cycle?;
      });
    } catch (e) {
      if (mounted) ToastNotification.showError(context, 'Failed to load cycles: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      pageTitle: 'Cycle Management',
      role: UserRole.admin,
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: LoadingSkeletonCard(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────
                  Row(
                    children: [
                      Text('Cycle Management',
                          style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.kTextPrimary)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _openCycleForm(null),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Create New Cycle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kBrandPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Active Cycle Card ────────────────────────────────
                  if (_active != null) ...[
                    _sectionTitle('Active Cycle'),
                    const SizedBox(height: 12),
                    _ActiveCycleCard(
                      cycle: _active!,
                      onEdit: () => _openCycleForm(_active),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ── Historical ───────────────────────────────────────
                  _sectionTitle('All Cycles'),
                  const SizedBox(height: 12),
                  if (_cycles.isEmpty)
                    const EmptyStateWidget(
                      title: 'No Cycles Yet',
                      subtitle: 'Create your first performance cycle.',
                      icon: Icons.calendar_today_rounded,
                    )
                  else
                    Column(
                      children: _cycles
                          .where((c) => c.id != _active?.id)
                          .map((c) => _CycleHistoryCard(
                                cycle: c,
                                onActivate: () => _activate(c.id),
                                onEdit: () => _openCycleForm(c),
                              ))
                          .toList(),
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

  Future<void> _activate(String cycleId) async {
    try {
      await ref.read(adminApiProvider).activateCycle(cycleId);
      if (!mounted) return;
      ToastNotification.showSuccess(context, 'Cycle activated.');
      _load();
    } catch (e) {
      if (mounted) ToastNotification.showError(context, 'Error: $e');
    }
  }

  void _openCycleForm(Cycle? cycle) {
    showDialog(
      context: context,
      builder: (_) => _CycleFormDialog(
        cycle: cycle,
        onSaved: _load,
      ),
    );
  }
}

// ── Active Cycle Card ─────────────────────────────────────────────────────────

class _ActiveCycleCard extends StatelessWidget {
  const _ActiveCycleCard({required this.cycle, required this.onEdit});
  final Cycle cycle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.kBrandPrimary,
            AppColors.kBrandPrimary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.kBrandPrimary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('● ACTIVE',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Edit Cycle'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(cycle.label.isNotEmpty ? cycle.label : 'FY ${cycle.year}',
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _phaseChip('Goal Setting', cycle.goalSetting),
              _phaseChip('Q1', cycle.q1),
              _phaseChip('Q2', cycle.q2),
              _phaseChip('Q3', cycle.q3),
              _phaseChip('Q4', cycle.q4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phaseChip(String name, PhaseWindow phase) {
    final now = DateTime.now();
    final open = _parseDate(phase.openDate);
    final close = _parseDate(phase.closeDate);
    final isOpen = open != null &&
        close != null &&
        now.isAfter(open) &&
        now.isBefore(close);
    final isUpcoming = open != null && now.isBefore(open);

    final statusColor = isOpen
        ? AppColors.kSuccess
        : isUpcoming
            ? AppColors.kWarning
            : Colors.white60;
    final statusLabel = isOpen
        ? 'Open'
        : isUpcoming
            ? 'Upcoming'
            : 'Closed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(statusLabel,
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${_fmt(phase.openDate)} → ${_fmt(phase.closeDate)}',
            style: GoogleFonts.inter(
                fontSize: 10, color: Colors.white.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _fmt(String? s) {
    final d = _parseDate(s);
    if (d == null) return '—';
    return DateFormat('MMM d, y').format(d);
  }
}

// ── History Card ──────────────────────────────────────────────────────────────

class _CycleHistoryCard extends StatelessWidget {
  const _CycleHistoryCard(
      {required this.cycle, required this.onActivate, required this.onEdit});
  final Cycle cycle;
  final VoidCallback onActivate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.kBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.kNeutral100,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('${cycle.year}',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.kTextPrimary)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cycle.label.isNotEmpty ? cycle.label : 'FY ${cycle.year}',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.kTextPrimary)),
                const SizedBox(height: 2),
                Text('Inactive',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.kTextSecondary)),
              ],
            ),
          ),
          TextButton(
              onPressed: onEdit,
              child: const Text('Edit')),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onActivate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kSuccess,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
  }
}

// ── Cycle Form Dialog ─────────────────────────────────────────────────────────

class _CycleFormDialog extends ConsumerStatefulWidget {
  const _CycleFormDialog({required this.cycle, required this.onSaved});
  final Cycle? cycle;
  final VoidCallback onSaved;

  @override
  ConsumerState<_CycleFormDialog> createState() => _CycleFormDialogState();
}

class _CycleFormDialogState extends ConsumerState<_CycleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _year;
  late String _label;
  bool _isSaving = false;

  // Phase dates: [openDate, closeDate] for each of 5 phases.
  final Map<String, List<DateTime?>> _phases = {
    'goal_setting': [null, null],
    'q1': [null, null],
    'q2': [null, null],
    'q3': [null, null],
    'q4': [null, null],
  };

  final _phaseLabels = {
    'goal_setting': 'Goal Setting',
    'q1': 'Q1',
    'q2': 'Q2',
    'q3': 'Q3',
    'q4': 'Q4',
  };

  @override
  void initState() {
    super.initState();
    final c = widget.cycle;
    _year = c?.year ?? DateTime.now().year;
    _label = c?.label ?? '';

    void loadPhase(String key, PhaseWindow pw) {
      _phases[key]![0] = _parse(pw.openDate);
      _phases[key]![1] = _parse(pw.closeDate);
    }

    if (c != null) {
      loadPhase('goal_setting', c.goalSetting);
      loadPhase('q1', c.q1);
      loadPhase('q2', c.q2);
      loadPhase('q3', c.q3);
      loadPhase('q4', c.q4);
    }
  }

  DateTime? _parse(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.cycle == null ? 'Create Cycle' : 'Edit Cycle',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: '$_year',
                        decoration: _dec('Year *'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final y = int.tryParse(v ?? '');
                          if (y == null || y < 2020) return 'Valid year required';
                          return null;
                        },
                        onChanged: (v) => _year = int.tryParse(v) ?? _year,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: _label,
                        decoration: _dec('Label (e.g. FY 2025–26)'),
                        onChanged: (v) => _label = v,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                ..._phases.entries.map((e) => _phaseRow(e.key)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        if (widget.cycle != null)
          ElevatedButton(
            onPressed: _isSaving
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    await _save(activate: true);
                  },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kSuccess,
                foregroundColor: Colors.white),
            child: const Text('Save & Activate'),
          ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kBrandPrimary,
              foregroundColor: Colors.white),
          child: Text(_isSaving
              ? 'Saving…'
              : (widget.cycle == null ? 'Create Cycle' : 'Save Cycle')),
        ),
      ],
    );
  }

  Widget _phaseRow(String key) {
    final label = _phaseLabels[key] ?? key;
    final dates = _phases[key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.kTextPrimary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                  child: _datePicker('Open Date', dates[0],
                      (d) => setState(() => dates[0] = d))),
              const SizedBox(width: 10),
              Expanded(
                  child: _datePicker('Close Date', dates[1],
                      (d) => setState(() => dates[1] = d))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datePicker(
      String label, DateTime? value, void Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: _dec(label),
        child: Text(
          value != null
              ? DateFormat('MMM d, y').format(value)
              : 'Select date',
          style: GoogleFonts.inter(
              fontSize: 13,
              color: value != null
                  ? AppColors.kTextPrimary
                  : AppColors.kTextSecondary),
        ),
      ),
    );
  }

  Future<void> _save({bool activate = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final api = ref.read(adminApiProvider);

    String toIso(DateTime? d) =>
        d?.toUtc().toIso8601String() ?? DateTime.now().toIso8601String();

    final body = {
      'year': _year,
      'label': _label.isNotEmpty ? _label : 'FY $_year',
      'goal_setting': {
        'open_date': toIso(_phases['goal_setting']![0]),
        'close_date': toIso(_phases['goal_setting']![1]),
      },
      'q1': {
        'open_date': toIso(_phases['q1']![0]),
        'close_date': toIso(_phases['q1']![1]),
      },
      'q2': {
        'open_date': toIso(_phases['q2']![0]),
        'close_date': toIso(_phases['q2']![1]),
      },
      'q3': {
        'open_date': toIso(_phases['q3']![0]),
        'close_date': toIso(_phases['q3']![1]),
      },
      'q4': {
        'open_date': toIso(_phases['q4']![0]),
        'close_date': toIso(_phases['q4']![1]),
      },
    };

    try {
      Cycle saved;
      if (widget.cycle == null) {
        saved = await api.createCycle(body);
      } else {
        saved = await api.updateCycle(widget.cycle!.id, body);
      }
      if (activate) {
        await api.activateCycle(saved.id);
      }
      if (mounted) {
        Navigator.pop(context);
        ToastNotification.showSuccess(
            context, 'Cycle saved${activate ? ' and activated' : ''}.');
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) ToastNotification.showError(context, 'Error: $e');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            fontSize: 12, color: AppColors.kTextSecondary),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}
