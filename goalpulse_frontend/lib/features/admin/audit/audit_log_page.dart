import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/toast_notification.dart';
import '../../../widgets/loading_skeleton.dart';
import '../admin_provider.dart';

class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  bool _isLoading = false;
  List<AuditLogEntry> _logs = [];
  int _total = 0;
  int _page = 1;

  // Filters.
  DateTime? _startDate;
  DateTime? _endDate;
  final _actorCtrl = TextEditingController();
  String _actionFilter = '';

  static const _actionOptions = [
    '',
    'goal_unlocked',
    'goal_approved',
    'goal_returned',
    'checkin_submitted',
    'checkin_reviewed',
    'cycle_created',
    'cycle_activated',
    'shared_goal_created',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _actorCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(adminApiProvider).getAuditLogs(
            startDate: _startDate?.toIso8601String(),
            endDate: _endDate?.toIso8601String(),
            actorId: _actorCtrl.text.trim().isNotEmpty
                ? _actorCtrl.text.trim()
                : null,
            action: _actionFilter.isNotEmpty ? _actionFilter : null,
            page: _page,
          );
      final list = (data['logs'] as List<dynamic>? ?? [])
          .map((j) => AuditLogEntry.fromJson(j as Map<String, dynamic>))
          .toList();
      setState(() {
        _logs = list;
        _total = data['total'] as int? ?? 0;
      });
    } catch (e) {
      if (mounted) ToastNotification.showError(context, 'Failed to load logs: $e');
    }
    setState(() => _isLoading = false);
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _actionFilter = '';
      _actorCtrl.clear();
      _page = 1;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      pageTitle: 'Audit Log',
      role: UserRole.admin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filter bar ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.kBorder.withValues(alpha: 0.4))),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Start date.
                _DateFilterChip(
                  label: 'From',
                  date: _startDate,
                  onPick: (d) => setState(() {
                    _startDate = d;
                    _page = 1;
                  }),
                ),
                // End date.
                _DateFilterChip(
                  label: 'To',
                  date: _endDate,
                  onPick: (d) => setState(() {
                    _endDate = d;
                    _page = 1;
                  }),
                ),
                // Actor ID.
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _actorCtrl,
                    decoration: InputDecoration(
                      labelText: 'Actor ID',
                      labelStyle: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.kTextSecondary),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    style: GoogleFonts.inter(fontSize: 12),
                    onSubmitted: (_) {
                      _page = 1;
                      _load();
                    },
                  ),
                ),
                // Action filter.
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _actionFilter,
                    decoration: InputDecoration(
                      labelText: 'Action Type',
                      labelStyle: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.kTextSecondary),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    style: GoogleFonts.inter(fontSize: 12),
                    items: _actionOptions
                        .map((a) => DropdownMenuItem(
                            value: a,
                            child: Text(a.isEmpty ? 'All Actions' : a)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _actionFilter = v ?? '';
                        _page = 1;
                      });
                      _load();
                    },
                  ),
                ),
                // Buttons.
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_rounded, size: 14),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: GoogleFonts.inter(fontSize: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ToastNotification.showSuccess(
                        context, 'Downloading audit log CSV…');
                  },
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Export CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kSuccess,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: GoogleFonts.inter(fontSize: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          // ── Summary bar ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
            child: Text(
              '$_total log entries found',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.kTextSecondary),
            ),
          ),

          // ── Table ────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: LoadingSkeletonTable(),
                  )
                : _logs.isEmpty
                    ? Center(
                        child: Text('No audit logs found.',
                            style: GoogleFonts.inter(
                                color: AppColors.kTextSecondary)))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                                AppColors.kNeutral100),
                            headingTextStyle: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.kTextSecondary),
                            dataTextStyle: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.kTextPrimary),
                            columnSpacing: 20,
                            dataRowMinHeight: 48,
                            dataRowMaxHeight: 64,
                            columns: const [
                              DataColumn(label: Text('Timestamp')),
                              DataColumn(label: Text('Actor')),
                              DataColumn(label: Text('Employee')),
                              DataColumn(label: Text('Action')),
                              DataColumn(label: Text('Field')),
                              DataColumn(label: Text('Old → New')),
                              DataColumn(label: Text('Reason')),
                            ],
                            rows: _logs.map((log) {
                              return DataRow(cells: [
                                DataCell(Text(
                                    _fmtTs(log.timestamp),
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.kTextSecondary))),
                                DataCell(_truncate(log.actorId, 12)),
                                DataCell(_truncate(log.employeeId, 12)),
                                DataCell(_actionChip(log.action)),
                                DataCell(Text(log.fieldChanged,
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic))),
                                DataCell(_valueDiff(log.oldValue, log.newValue)),
                                DataCell(
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 200),
                                    child: Text(
                                      log.reason.isNotEmpty ? log.reason : '—',
                                      style: GoogleFonts.inter(fontSize: 11),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          ),

          // ── Pagination ───────────────────────────────────────────────
          if (!_isLoading)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _load();
                          }
                        : null,
                    child: const Text('← Prev'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Page $_page',
                        style: GoogleFonts.inter(fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: _logs.length == 50
                        ? () {
                            setState(() => _page++);
                            _load();
                          }
                        : null,
                    child: const Text('Next →'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _truncate(String s, int max) {
    final t = s.length > max ? '…${s.substring(s.length - max)}' : s;
    return Tooltip(message: s, child: Text(t));
  }

  String _fmtTs(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      return DateFormat('MMM d, y HH:mm').format(d);
    } catch (_) {
      return ts;
    }
  }

  Widget _actionChip(String action) {
    final (color, icon) = switch (action) {
      'goal_unlocked' => (AppColors.kDanger, Icons.lock_open_rounded),
      'goal_approved' => (AppColors.kSuccess, Icons.check_circle_outline),
      'goal_returned' => (AppColors.kWarning, Icons.undo_rounded),
      'checkin_submitted' => (AppColors.kInfo, Icons.upload_rounded),
      'checkin_reviewed' => (AppColors.kBrandSecondary, Icons.rate_review_outlined),
      'cycle_activated' => (AppColors.kBrandPrimary, Icons.power_settings_new_rounded),
      _ => (AppColors.kTextSecondary, Icons.history_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(action.replaceAll('_', ' '),
              style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _valueDiff(dynamic oldVal, dynamic newVal) {
    if (oldVal == null && newVal == null) return const Text('—');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (oldVal != null)
          Text('$oldVal',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  decoration: TextDecoration.lineThrough,
                  color: AppColors.kDanger)),
        if (oldVal != null && newVal != null)
          const Text(' → ',
              style: TextStyle(color: AppColors.kTextSecondary)),
        if (newVal != null)
          Text('$newVal',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.kSuccess)),
      ],
    );
  }
}

// ── Date Filter Chip ──────────────────────────────────────────────────────────

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip(
      {required this.label, required this.date, required this.onPick});
  final String label;
  final DateTime? date;
  final void Function(DateTime) onPick;

  @override
  Widget build(BuildContext context) {
    final text = date != null
        ? DateFormat('MMM d, y').format(date!)
        : 'Any';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
              color: date != null
                  ? AppColors.kBrandPrimary
                  : AppColors.kBorder.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
          color: date != null
              ? AppColors.kBrandPrimary.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 13,
                color: date != null
                    ? AppColors.kBrandPrimary
                    : AppColors.kTextSecondary),
            const SizedBox(width: 5),
            Text('$label: $text',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: date != null
                        ? AppColors.kBrandPrimary
                        : AppColors.kTextSecondary)),
          ],
        ),
      ),
    );
  }
}
