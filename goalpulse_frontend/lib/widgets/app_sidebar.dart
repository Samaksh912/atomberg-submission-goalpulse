import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../core/constants.dart';

/// Navigation item descriptor.
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.path,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final String path;
  final int? badgeCount;
}

/// Sidebar collapse state — global so AppTopBar menu toggle can access it.
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

/// Collapsible sidebar for the GoalPulse app shell.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.role,
    required this.userName,
    required this.userRole,
  });

  final UserRole role;
  final String userName;
  final String userRole;

  // ── Nav items per role ──────────────────────────────────────────────────

  static List<NavItem> navItemsFor(UserRole role) => switch (role) {
        UserRole.employee => const [
            NavItem(label: 'Dashboard', icon: Icons.home_outlined, path: '/employee/dashboard'),
            NavItem(label: 'My Goals', icon: Icons.track_changes_outlined, path: '/employee/goals'),
            NavItem(label: 'Check-Ins', icon: Icons.checklist_outlined, path: '/employee/checkins'),
            NavItem(label: 'My Progress', icon: Icons.bar_chart_outlined, path: '/employee/progress'),
          ],
        UserRole.manager => const [
            NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, path: '/manager/dashboard'),
            NavItem(label: 'Approvals', icon: Icons.approval_outlined, path: '/manager/approvals', badgeCount: 3),
            NavItem(label: 'Team Check-Ins', icon: Icons.group_outlined, path: '/manager/checkins'),
            NavItem(label: 'Shared Goals', icon: Icons.share_outlined, path: '/manager/shared-goals'),
            NavItem(label: 'Analytics', icon: Icons.analytics_outlined, path: '/manager/analytics'),
          ],
        UserRole.admin => const [
            NavItem(label: 'Dashboard', icon: Icons.admin_panel_settings_outlined, path: '/admin/dashboard'),
            NavItem(label: 'Users', icon: Icons.manage_accounts_outlined, path: '/admin/users'),
            NavItem(label: 'Cycles', icon: Icons.calendar_month_outlined, path: '/admin/cycles'),
            NavItem(label: 'Shared Goals', icon: Icons.share_outlined, path: '/admin/shared-goals'),
            NavItem(label: 'Escalations', icon: Icons.warning_amber_outlined, path: '/admin/escalations'),
            NavItem(label: 'Audit Log', icon: Icons.history_outlined, path: '/admin/audit-log'),
            NavItem(label: 'Analytics', icon: Icons.bar_chart_outlined, path: '/admin/analytics'),
            NavItem(label: 'Reports', icon: Icons.summarize_outlined, path: '/admin/reports'),
          ],
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(sidebarExpandedProvider);
    final items = navItemsFor(role);
    final currentPath = GoRouterState.of(context).matchedLocation;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: expanded ? 260 : 72,
      decoration: const BoxDecoration(
        color: AppColors.kCardBackground,
        border: Border(right: BorderSide(color: AppColors.kBorder, width: 1)),
      ),
      child: Column(
        children: [
          // ── Logo area ──────────────────────────────────────────────────
          _LogoArea(expanded: expanded),
          const Divider(height: 1),

          // ── Nav items ──────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: items
                  .map((item) => _NavTile(
                        item: item,
                        expanded: expanded,
                        isActive: currentPath == item.path ||
                            (currentPath.startsWith(item.path) &&
                                item.path != _rolePrefix(role)),
                      ))
                  .toList(),
            ),
          ),

          // ── Collapse toggle ────────────────────────────────────────────
          const Divider(height: 1),
          _CollapseToggle(expanded: expanded),

          // ── User info ──────────────────────────────────────────────────
          const Divider(height: 1),
          _UserInfoArea(
            expanded: expanded,
            userName: userName,
            userRole: userRole,
          ),
        ],
      ),
    );
  }

  String _rolePrefix(UserRole r) => switch (r) {
        UserRole.employee => '/employee',
        UserRole.manager => '/manager',
        UserRole.admin => '/admin',
      };
}

// ── Logo area ──────────────────────────────────────────────────────────────

class _LogoArea extends StatelessWidget {
  const _LogoArea({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: expanded ? 20 : 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.kBrandPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                'GP',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            if (expanded) ...[
              const SizedBox(width: 12),
              Text(
                'GoalPulse',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.kTextPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Single nav tile ────────────────────────────────────────────────────────

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.expanded,
    required this.isActive,
  });

  final NavItem item;
  final bool expanded;
  final bool isActive;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final expanded = widget.expanded;

    Color bgColor;
    if (isActive) {
      bgColor = AppColors.kBrandPrimary.withAlpha(25);
    } else if (_hovering) {
      bgColor = AppColors.kNeutral100;
    } else {
      bgColor = Colors.transparent;
    }

    final fgColor = isActive ? AppColors.kBrandPrimary : AppColors.kTextSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: () => context.go(widget.item.path),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 42,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? const Border(
                      left: BorderSide(color: AppColors.kBrandPrimary, width: 3),
                    )
                  : null,
            ),
            padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(widget.item.icon, size: 20, color: fgColor),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: fgColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.item.badgeCount != null && widget.item.badgeCount! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.kDanger,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${widget.item.badgeCount}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Collapse toggle ────────────────────────────────────────────────────────

class _CollapseToggle extends ConsumerWidget {
  const _CollapseToggle({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () =>
          ref.read(sidebarExpandedProvider.notifier).state = !expanded,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment:
              expanded ? MainAxisAlignment.end : MainAxisAlignment.center,
          children: [
            if (expanded) const Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
              child: Icon(
                expanded
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: AppColors.kTextSecondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── User info area ─────────────────────────────────────────────────────────

class _UserInfoArea extends StatelessWidget {
  const _UserInfoArea({
    required this.expanded,
    required this.userName,
    required this.userRole,
  });

  final bool expanded;
  final String userName;
  final String userRole;

  @override
  Widget build(BuildContext context) {
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return SizedBox(
      height: 64,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
        child: Row(
          mainAxisAlignment:
              expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.kBrandPrimary,
              child: Text(
                initial,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            if (expanded) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.kTextPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.kBrandPrimary.withAlpha(20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        userRole,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.kBrandPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
