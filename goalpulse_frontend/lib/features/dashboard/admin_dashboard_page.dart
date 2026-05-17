import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/loading_skeleton.dart';
import '../admin/admin_provider.dart';

/// Real admin dashboard — org-wide KPI cards, cycle status, recent audit log,
/// and quick-action cards.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(orgStatsProvider);
    final cycleAsync = ref.watch(activeCycleProvider);

    return AppShell(
      pageTitle: 'Admin Dashboard',
      role: UserRole.admin,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting ─────────────────────────────────────────────
            Text('Admin Overview',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.kTextPrimary)),
            const SizedBox(height: 4),
            Text('Organisation-wide goal-setting health at a glance.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.kTextSecondary)),
            const SizedBox(height: 24),

            // ── Row 1: KPI Cards ─────────────────────────────────────
            statsAsync.when(
              loading: () => _kpiSkeleton(),
              error: (e, _) => _errorCard('Failed to load stats: $e'),
              data: (stats) => _KpiRow(stats: stats),
            ),
            const SizedBox(height: 24),

            // ── Row 2: Cycle status + Audit log ──────────────────────
            LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth > 700;
              final children = [
                Expanded(
                    flex: 3,
                    child: cycleAsync.when(
                      loading: () => const LoadingSkeletonCard(),
                      error: (e, _) => _errorCard('Cycle unavailable'),
                      data: (cycle) => _CycleStatusCard(cycle: cycle),
                    )),
                if (wide) const SizedBox(width: 16),
                if (wide)
                  Expanded(flex: 2, child: _RecentAuditCard(ref: ref)),
              ];
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children)
                  : Column(children: children);
            }),
            const SizedBox(height: 24),

            // ── Row 3: Quick Actions ──────────────────────────────────
            _sectionTitle('Quick Actions'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _QuickActionCard(
                  icon: Icons.people_alt_rounded,
                  label: 'Manage Users',
                  color: AppColors.kBrandPrimary,
                  onTap: () => context.go('/admin/users'),
                ),
                _QuickActionCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'Configure Cycle',
                  color: AppColors.kBrandSecondary,
                  onTap: () => context.go('/admin/cycles'),
                ),
                _QuickActionCard(
                  icon: Icons.history_rounded,
                  label: 'View Audit Log',
                  color: AppColors.kWarning,
                  onTap: () => context.go('/admin/audit-log'),
                ),
                _QuickActionCard(
                  icon: Icons.lock_open_rounded,
                  label: 'Goal Unlock',
                  color: AppColors.kDanger,
                  onTap: () => context.go('/admin/goal-unlock'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiSkeleton() => Row(
        children: List.generate(
          5,
          (_) => const Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 12),
              child: LoadingSkeletonCard(),
            ),
          ),
        ),
      );

  Widget _errorCard(String msg) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.kDanger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(msg,
            style: GoogleFonts.inter(color: AppColors.kDanger, fontSize: 13)),
      );

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.kTextPrimary));
}

// ── KPI Row ───────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.stats});
  final OrgStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiData(
        label: 'Total Employees',
        value: '${stats.totalEmployees}',
        icon: Icons.people_alt_rounded,
        color: AppColors.kBrandPrimary,
      ),
      _KpiData(
        label: 'Goals Submitted',
        value: '${stats.goalsSubmitted}',
        icon: Icons.upload_file_rounded,
        color: AppColors.kInfo,
      ),
      _KpiData(
        label: 'Goals Approved',
        value: '${stats.goalsApproved}',
        icon: Icons.verified_rounded,
        color: AppColors.kSuccess,
      ),
      _KpiData(
        label: 'Pending Approvals',
        value: '${stats.pendingApprovals}',
        icon: Icons.hourglass_empty_rounded,
        color: AppColors.kWarning,
      ),
      _KpiData(
        label: 'Check-In Rate',
        value: '${stats.checkinCompletionRate}%',
        icon: Icons.track_changes_rounded,
        color: AppColors.kBrandSecondary,
        subtitle: 'Coming in Phase 9',
      ),
    ];

    return Row(
      children: cards
          .asMap()
          .entries
          .map((e) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: e.key < cards.length - 1 ? 12 : 0),
                  child: _KpiCard(data: e.value),
                ),
              ))
          .toList(),
    );
  }
}

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  const _KpiData(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      this.subtitle});
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, size: 18, color: data.color),
          ),
          const SizedBox(height: 12),
          Text(data.value,
              style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.kTextPrimary)),
          const SizedBox(height: 2),
          Text(data.label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.kTextSecondary)),
          if (data.subtitle != null)
            Text(data.subtitle!,
                style: GoogleFonts.inter(
                    fontSize: 9,
                    color: AppColors.kTextSecondary,
                    fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

// ── Cycle Status Card ─────────────────────────────────────────────────────────

class _CycleStatusCard extends StatelessWidget {
  const _CycleStatusCard({required this.cycle});
  final Cycle? cycle;

  @override
  Widget build(BuildContext context) {
    if (cycle == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.kCardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.kBorder.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Cycle Status', Icons.calendar_month_rounded,
                AppColors.kWarning),
            const SizedBox(height: 12),
            Text('No active cycle configured.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.kTextSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go('/admin/cycles'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kBrandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Configure Cycle'),
            ),
          ],
        ),
      );
    }

    final phases = [
      ('Goal Setting', cycle!.goalSetting),
      ('Q1', cycle!.q1),
      ('Q2', cycle!.q2),
      ('Q3', cycle!.q3),
      ('Q4', cycle!.q4),
    ];

    return Container(
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
          _cardTitle('Cycle Status', Icons.calendar_month_rounded,
              AppColors.kBrandPrimary),
          const SizedBox(height: 4),
          Text(
            cycle!.label.isNotEmpty ? cycle!.label : 'FY ${cycle!.year}',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.kTextPrimary),
          ),
          const SizedBox(height: 16),
          ...phases.map((p) => _PhaseRow(name: p.$1, window: p.$2)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/admin/cycles'),
            child: const Text('Manage Cycles →'),
          ),
        ],
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({required this.name, required this.window});
  final String name;
  final PhaseWindow window;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final open = _parse(window.openDate);
    final close = _parse(window.closeDate);
    final isOpen = open != null && close != null &&
        now.isAfter(open) && now.isBefore(close);
    final isUpcoming = open != null && now.isBefore(open);
    final daysLeft = close != null && isOpen
        ? close.difference(now).inDays
        : null;

    final (statusColor, statusLabel) = isOpen
        ? (AppColors.kSuccess, 'Open')
        : isUpcoming
            ? (AppColors.kWarning, 'Upcoming')
            : (AppColors.kTextSecondary, 'Closed');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(name,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.kTextPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(statusLabel,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_fmt(window.openDate)} → ${_fmt(window.closeDate)}',
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.kTextSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (daysLeft != null)
            Text('$daysLeft d left',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.kSuccess)),
        ],
      ),
    );
  }

  DateTime? _parse(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _fmt(String? s) {
    final d = _parse(s);
    if (d == null) return '—';
    return DateFormat('MMM d').format(d);
  }
}

// ── Recent Audit Log Card ─────────────────────────────────────────────────────

class _RecentAuditCard extends StatefulWidget {
  const _RecentAuditCard({required this.ref});
  final WidgetRef ref;

  @override
  State<_RecentAuditCard> createState() => _RecentAuditCardState();
}

class _RecentAuditCardState extends State<_RecentAuditCard> {
  bool _loading = true;
  List<AuditLogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.ref.read(adminApiProvider).getAuditLogs(page: 1);
      final list = (data['logs'] as List<dynamic>? ?? [])
          .take(5)
          .map((j) => AuditLogEntry.fromJson(j as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => _logs = list);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _cardTitle(
              'Recent Audit Log', Icons.history_rounded, AppColors.kWarning),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_logs.isEmpty)
            Text('No audit entries yet.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.kTextSecondary))
          else
            ..._logs.map((log) => _AuditRow(log: log)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/admin/audit-log'),
            child: const Text('View Full Log →'),
          ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.log});
  final AuditLogEntry log;

  @override
  Widget build(BuildContext context) {
    final ts = _fmtTs(log.timestamp);
    final actionColor = switch (log.action) {
      'goal_unlocked' => AppColors.kDanger,
      'goal_approved' => AppColors.kSuccess,
      'goal_returned' => AppColors.kWarning,
      _ => AppColors.kTextSecondary,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: BoxDecoration(
              color: actionColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.action.replaceAll('_', ' '),
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: actionColor),
                ),
                Text(ts,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.kTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTs(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      return DateFormat('MMM d, HH:mm').format(d);
    } catch (_) {
      return ts;
    }
  }
}

// ── Quick Action Card ─────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.kTextPrimary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _cardTitle(String title, IconData icon, Color color) {
  return Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(title,
          style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.kTextPrimary)),
    ],
  );
}
