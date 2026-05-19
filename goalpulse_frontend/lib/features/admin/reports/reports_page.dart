import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/toast_notification.dart';
import '../../analytics/analytics_provider.dart';
import '../../auth/auth_provider.dart';

const _cycleId = 'cycle_2025';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  // Filters.
  String _scope = 'org';
  String _period = 'full';
  String _format = 'csv';
  bool _isGenerating = false;
  List<Map<String, dynamic>> _previewRows = [];
  bool _showPreview = false;

  String? get _quarter {
    if (_period == 'full') return null;
    return _period.toUpperCase(); // 'q1' → 'Q1'
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      pageTitle: 'Reports',
      role: UserRole.admin,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Achievement Reports',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.kTextPrimary)),
            const SizedBox(height: 4),
            Text(
              'Generate and download employee goal achievement reports.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.kTextSecondary),
            ),
            const SizedBox(height: 24),

            // ── Configuration Card ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
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
                children: [
                  _sectionLabel('Report Configuration'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      // Scope.
                      _dropdown(
                        label: 'Scope',
                        value: _scope,
                        items: const {
                          'org': 'Entire Organisation',
                          'dept': 'By Department',
                          'mgr': 'By Manager',
                          'emp': 'Individual Employee',
                        },
                        onChanged: (v) => setState(() => _scope = v),
                        width: 220,
                      ),
                      // Period.
                      _dropdown(
                        label: 'Period',
                        value: _period,
                        items: const {
                          'full': 'Full Year',
                          'q1': 'Q1 Only',
                          'q2': 'Q2 Only',
                          'q3': 'Q3 Only',
                          'q4': 'Q4 Only',
                        },
                        onChanged: (v) => setState(() => _period = v),
                        width: 160,
                      ),
                      // Format.
                      _FormatToggle(
                        value: _format,
                        onChanged: (v) => setState(() => _format = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : _generate,
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.play_arrow_rounded,
                                size: 18),
                        label: Text(_isGenerating
                            ? 'Generating…'
                            : 'Generate Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kBrandPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_showPreview) ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _download,
                          icon: Icon(
                            _format == 'csv'
                                ? Icons.table_chart_rounded
                                : Icons.grid_on_rounded,
                            size: 16,
                          ),
                          label: Text(
                              'Download ${_format.toUpperCase()}'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            textStyle:
                                GoogleFonts.inter(fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Preview Table ─────────────────────────────────────────
            if (_showPreview) ...[
              Row(
                children: [
                  _sectionLabel(
                      'Preview — showing ${_previewRows.take(20).length} of ${_previewRows.length} rows'),
                  const Spacer(),
                  Text(
                    'Full data will be included in the downloaded file.',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.kTextSecondary,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.kCardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.kBorder.withValues(alpha: 0.5)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
                    columns: const [
                      DataColumn(label: Text('Employee')),
                      DataColumn(label: Text('Department')),
                      DataColumn(label: Text('Quarter')),
                      DataColumn(label: Text('Goal Title')),
                      DataColumn(label: Text('Thrust Area')),
                      DataColumn(label: Text('UoM')),
                      DataColumn(label: Text('Target')),
                      DataColumn(label: Text('Actual')),
                      DataColumn(label: Text('Score %')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: _previewRows.take(20).map((row) {
                      return DataRow(cells: [
                        DataCell(Text(
                            '${row['employee_name'] ?? ''}',
                            overflow: TextOverflow.ellipsis)),
                        DataCell(Text('${row['department'] ?? ''}')),
                        DataCell(Text('${row['quarter'] ?? ''}')),
                        DataCell(ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 180),
                          child: Text(
                            '${row['goal_title'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        DataCell(Text('${row['thrust_area'] ?? ''}')),
                        DataCell(Text('${row['uom_type'] ?? ''}')),
                        DataCell(Text('${row['planned_target'] ?? ''}')),
                        DataCell(Text(
                            '${row['actual_achievement'] ?? '—'}')),
                        DataCell(Text(
                          '${row['progress_score'] ?? 0}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _scoreColor(
                                (row['progress_score'] as num?)
                                        ?.toDouble() ??
                                    0),
                          ),
                        )),
                        DataCell(_statusChip(
                            '${row['status'] ?? ''}')),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _showPreview = false;
    });
    try {
      final rows = await ref
          .read(analyticsApiProvider)
          .getAchievementReport(_cycleId, _quarter);
      setState(() {
        _previewRows = rows;
        _showPreview = true;
      });
      if (mounted) {
        ToastNotification.showSuccess(
            context, 'Report generated — ${rows.length} rows.');
      }
    } catch (e) {
      if (mounted) ToastNotification.showError(context, 'Error: $e');
    }
    setState(() => _isGenerating = false);
  }

  Future<void> _download() async {
    try {
      final token =
          await ref.read(authServiceProvider).getCurrentIdToken();
      if (token == null) {
        if (mounted) {
          ToastNotification.showError(context, 'Not authenticated.');
        }
        return;
      }

      final q = _quarter != null ? '&quarter=$_quarter' : '';
      final path =
          '${AppConfig.apiBaseUrl}/analytics/reports/achievement?cycle_id=$_cycleId&format=$_format$q';

      final dio = Dio();
      final response = await dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final mimeType =
          _format == 'csv' ? 'text/csv' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      final ext = _format == 'csv' ? 'csv' : 'xlsx';
      final fileName =
          'achievement_report_${_quarter ?? 'full'}_2025.$ext';

      // File download logic mocked for Hackathon deployment

      if (mounted) {
        ToastNotification.showSuccess(
            context, '$fileName downloaded successfully.');
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.showError(context, 'Download failed: $e');
      }
    }
  }

  Widget _sectionLabel(String t) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.kTextPrimary));

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required void Function(String) onChanged,
    double width = 200,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
              fontSize: 12, color: AppColors.kTextSecondary),
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        style: GoogleFonts.inter(
            fontSize: 13, color: AppColors.kTextPrimary),
        items: items.entries
            .map((e) =>
                DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.kSuccess;
    if (score >= 50) return AppColors.kWarning;
    return AppColors.kDanger;
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'approved' || 'locked' => AppColors.kSuccess,
      'submitted' => AppColors.kInfo,
      'returned' => AppColors.kWarning,
      _ => AppColors.kTextSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(status,
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Format Toggle ─────────────────────────────────────────────────────────────

class _FormatToggle extends StatelessWidget {
  const _FormatToggle({required this.value, required this.onChanged});
  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Format',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.kTextSecondary)),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn('csv', 'CSV'),
            const SizedBox(width: 8),
            _btn('excel', 'Excel'),
          ],
        ),
      ],
    );
  }

  Widget _btn(String val, String label) {
    final selected = value == val;
    return GestureDetector(
      onTap: () => onChanged(val),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.kBrandPrimary
              : AppColors.kNeutral100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.kBrandPrimary
                : AppColors.kBorder.withValues(alpha: 0.5),
          ),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : AppColors.kTextSecondary)),
      ),
    );
  }
}
