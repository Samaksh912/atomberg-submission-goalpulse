import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/toast_notification.dart';
import '../admin_provider.dart';

class GoalUnlockPage extends ConsumerStatefulWidget {
  const GoalUnlockPage({super.key});

  @override
  ConsumerState<GoalUnlockPage> createState() => _GoalUnlockPageState();
}

class _GoalUnlockPageState extends ConsumerState<GoalUnlockPage> {
  final _searchCtrl = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _goalSheets = [];
  final Set<String> _expandedSheetIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final sheets = await ref.read(adminApiProvider).getAllGoals();
      // Only show approved/locked sheets with at least one goal item.
      final filtered = sheets
          .where((s) =>
              (s['sheet_status'] == 'approved' ||
                  s['sheet_status'] == 'locked') &&
              ((s['goals'] as List?) ?? []).isNotEmpty)
          .toList();

      // Filter by search term.
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _goalSheets = q.isEmpty
            ? filtered
            : filtered
                .where((s) =>
                    (s['employee_name'] ?? '').toLowerCase().contains(q) ||
                    (s['employee_email'] ?? '').toLowerCase().contains(q) ||
                    (s['employee_id'] ?? '').toLowerCase().contains(q))
                .toList();
      });
    } catch (e) {
      if (mounted) ToastNotification.showError(context, 'Failed to load goals: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      pageTitle: 'Goal Unlock',
      role: UserRole.admin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header + search ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Goal Unlock',
                          style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.kTextPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        'Unlock individual goal items for approved sheets. Every action is audit-logged.',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.kTextSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search employee by name or email…',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.kTextSecondary),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: AppColors.kTextSecondary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppColors.kBorder.withValues(alpha: 0.5)),
                      ),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) => _load(),
                    onChanged: (_) => _load(),
                  ),
                ),
              ],
            ),
          ),

          // ── Results ─────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _goalSheets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline_rounded,
                                size: 48, color: AppColors.kTextSecondary),
                            const SizedBox(height: 12),
                            Text(
                              'No approved goal sheets found.',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: AppColors.kTextSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: _goalSheets.length,
                        itemBuilder: (context, i) {
                          final sheet = _goalSheets[i];
                          final sheetId = sheet['id'] as String? ?? '';
                          final isExpanded =
                              _expandedSheetIds.contains(sheetId);
                          return _EmployeeGoalCard(
                            sheet: sheet,
                            isExpanded: isExpanded,
                            onToggle: () => setState(() {
                              if (isExpanded) {
                                _expandedSheetIds.remove(sheetId);
                              } else {
                                _expandedSheetIds.add(sheetId);
                              }
                            }),
                            onUnlocked: _load,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Employee Goal Card ────────────────────────────────────────────────────────

class _EmployeeGoalCard extends ConsumerWidget {
  const _EmployeeGoalCard({
    required this.sheet,
    required this.isExpanded,
    required this.onToggle,
    required this.onUnlocked,
  });

  final Map<String, dynamic> sheet;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onUnlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheetId = sheet['id'] as String? ?? '';
    final employeeName = sheet['employee_name'] as String? ??
        sheet['employee_email'] as String? ??
        sheet['employee_id'] as String? ??
        'Unknown';
    final dept = sheet['employee_department'] as String? ?? '';
    final status = sheet['sheet_status'] as String? ?? '';
    final goals = (sheet['goals'] as List<dynamic>? ?? []);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isExpanded
                ? AppColors.kBrandPrimary.withValues(alpha: 0.4)
                : AppColors.kBorder.withValues(alpha: 0.5)),
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
          // Header row — tap to expand.
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AppColors.kBrandPrimary.withValues(alpha: 0.12),
                    child: Text(
                      employeeName.isNotEmpty ? employeeName[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppColors.kBrandPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(employeeName,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.kTextPrimary)),
                        if (dept.isNotEmpty)
                          Text(dept,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.kTextSecondary)),
                      ],
                    ),
                  ),
                  _statusBadge(status),
                  const SizedBox(width: 8),
                  Text('${goals.length} goals',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.kTextSecondary)),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded,
                        color: AppColors.kTextSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Expanded goal items.
          if (isExpanded)
            Column(
              children: [
                Divider(
                    height: 1,
                    color: AppColors.kBorder.withValues(alpha: 0.4)),
                ...goals.map((g) => _GoalItemRow(
                      goalItem: g as Map<String, dynamic>,
                      sheetId: sheetId,
                      employeeName: employeeName,
                      onUnlocked: onUnlocked,
                    )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(String s) {
    final isApproved = s == 'approved' || s == 'locked';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isApproved ? AppColors.kSuccess : AppColors.kWarning)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        isApproved ? 'Approved' : s,
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isApproved ? AppColors.kSuccess : AppColors.kWarning),
      ),
    );
  }
}

// ── Goal Item Row ─────────────────────────────────────────────────────────────

class _GoalItemRow extends ConsumerWidget {
  const _GoalItemRow({
    required this.goalItem,
    required this.sheetId,
    required this.employeeName,
    required this.onUnlocked,
  });

  final Map<String, dynamic> goalItem;
  final String sheetId;
  final String employeeName;
  final VoidCallback onUnlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = goalItem['title'] as String? ?? 'Untitled';
    final thrustArea = goalItem['thrust_area'] as String? ?? '';
    final isLocked = goalItem['is_locked'] as bool? ?? false;
    final goalItemId = goalItem['goal_item_id'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: AppColors.kBorder.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 40), // indent under avatar.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.kTextPrimary)),
                if (thrustArea.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(thrustArea,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.kTextSecondary)),
                ],
              ],
            ),
          ),
          // Lock status badge.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isLocked ? AppColors.kDanger : AppColors.kSuccess)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLocked
                      ? Icons.lock_outline_rounded
                      : Icons.lock_open_rounded,
                  size: 12,
                  color: isLocked ? AppColors.kDanger : AppColors.kSuccess,
                ),
                const SizedBox(width: 4),
                Text(
                  isLocked ? 'Locked' : 'Unlocked',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isLocked
                          ? AppColors.kDanger
                          : AppColors.kSuccess),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Unlock button (only if locked).
          if (isLocked)
            ElevatedButton.icon(
              onPressed: () => _showUnlockDialog(
                  context, ref, title, goalItemId),
              icon: const Icon(Icons.lock_open_rounded, size: 14),
              label: const Text('Unlock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kDanger,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  void _showUnlockDialog(BuildContext context, WidgetRef ref,
      String goalTitle, String goalItemId) {
    final reasonCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock_open_rounded,
                  color: AppColors.kDanger, size: 22),
              const SizedBox(width: 8),
              Text('Unlock Goal Item',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kDanger)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.kTextPrimary),
                    children: [
                      const TextSpan(text: 'You are about to unlock '),
                      TextSpan(
                          text: '"$goalTitle"',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' for '),
                      TextSpan(
                          text: employeeName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(
                          text:
                              '.\n\nThis action is permanently recorded in the audit log.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Reason for unlock *',
                    labelStyle: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.kTextSecondary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (reasonCtrl.text.trim().isEmpty) {
                        ToastNotification.showError(
                            ctx, 'A reason is required.');
                        return;
                      }
                      setDlg(() => isSaving = true);
                      try {
                        await ref.read(adminApiProvider).unlockGoalItem(
                            sheetId, goalItemId, reasonCtrl.text.trim());
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ToastNotification.showSuccess(context,
                              'Goal unlocked. Audit log updated.');
                          onUnlocked();
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ToastNotification.showError(ctx, 'Error: $e');
                        }
                      }
                      setDlg(() => isSaving = false);
                    },
              icon: isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_open_rounded, size: 14),
              label: const Text('Unlock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kDanger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
