import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../features/auth/auth_provider.dart';
import 'app_sidebar.dart';

// ── Notifications provider (stub — will be backed by Firestore later) ────

final notificationsProvider = StateProvider<List<Map<String, String>>>((ref) => [
      {'title': 'Q1 Check-in Reminder', 'body': 'Submit your Q1 actuals before March 31.', 'time': '2h ago'},
      {'title': 'Goal Approved', 'body': 'Your manager approved "Increase NPS"', 'time': '5h ago'},
      {'title': 'New Shared Goal', 'body': 'A shared goal has been assigned to your team.', 'time': '1d ago'},
    ]);

/// Top bar displayed above the content area in the app shell.
class AppTopBar extends ConsumerWidget {
  const AppTopBar({super.key, required this.pageTitle});

  final String pageTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unread = notifications.length;
    final profile = ref.watch(currentUserProfileProvider);
    final displayName = profile.valueOrNull?['displayName'] as String? ?? 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: AppColors.kCardBackground,
        border: Border(bottom: BorderSide(color: AppColors.kBorder, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ── Menu toggle ────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 22),
            color: AppColors.kTextSecondary,
            tooltip: 'Toggle sidebar',
            onPressed: () {
              final expanded = ref.read(sidebarExpandedProvider);
              ref.read(sidebarExpandedProvider.notifier).state = !expanded;
            },
          ),
          const SizedBox(width: 8),

          // ── Page title ─────────────────────────────────────────────────
          Text(
            pageTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.kTextPrimary,
            ),
          ),

          const Spacer(),

          // ── Cycle phase chip ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.kSuccess.withAlpha(20),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.kSuccess,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Q1 Check-in Window Open',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.kSuccess,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── Notification bell ──────────────────────────────────────────
          _NotificationBell(unreadCount: unread),

          // ── Divider ────────────────────────────────────────────────────
          Container(
            height: 28,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: AppColors.kBorder,
          ),

          // ── User avatar + dropdown ─────────────────────────────────────
          _UserDropdown(initial: initial, displayName: displayName),
        ],
      ),
    );
  }
}

// ── Notification bell ──────────────────────────────────────────────────────

class _NotificationBell extends ConsumerStatefulWidget {
  const _NotificationBell({required this.unreadCount});
  final int unreadCount;

  @override
  ConsumerState<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<_NotificationBell> {
  OverlayEntry? _overlay;

  void _togglePanel() {
    if (_overlay != null) {
      _overlay!.remove();
      _overlay = null;
      return;
    }
    _overlay = OverlayEntry(
      builder: (ctx) => _NotificationPanel(
        onClose: () {
          _overlay?.remove();
          _overlay = null;
        },
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Badge(
        isLabelVisible: widget.unreadCount > 0,
        label: Text('${widget.unreadCount}',
            style: const TextStyle(fontSize: 10)),
        child: const Icon(Icons.notifications_outlined, size: 22),
      ),
      color: AppColors.kTextSecondary,
      tooltip: 'Notifications',
      onPressed: _togglePanel,
    );
  }
}

// ── Notification panel (right-side overlay) ────────────────────────────────

class _NotificationPanel extends ConsumerWidget {
  const _NotificationPanel({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Stack(
      children: [
        // Scrim
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(color: Colors.black.withAlpha(20)),
          ),
        ),
        // Panel
        Positioned(
          top: 60,
          right: 0,
          bottom: 0,
          width: 360,
          child: Material(
            elevation: 8,
            shadowColor: Colors.black.withAlpha(30),
            child: Container(
              color: AppColors.kCardBackground,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Text('Notifications',
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.kTextPrimary)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            ref.read(notificationsProvider.notifier).state = [];
                            onClose();
                          },
                          child: Text('Mark all read',
                              style: GoogleFonts.inter(fontSize: 12)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // List
                  Expanded(
                    child: notifications.isEmpty
                        ? Center(
                            child: Text('No new notifications',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.kTextSecondary)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(0),
                            itemCount: notifications.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final n = notifications[i];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                leading: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.kBrandPrimary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                      Icons.notifications_outlined,
                                      size: 18,
                                      color: AppColors.kBrandPrimary),
                                ),
                                title: Text(n['title'] ?? '',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(n['body'] ?? '',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.kTextSecondary)),
                                    const SizedBox(height: 4),
                                    Text(n['time'] ?? '',
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.kTextSecondary
                                                .withAlpha(160))),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── User dropdown ──────────────────────────────────────────────────────────

class _UserDropdown extends ConsumerWidget {
  const _UserDropdown({
    required this.initial,
    required this.displayName,
  });

  final String initial;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (value) async {
        if (value == 'logout') {
          await ref.read(authServiceProvider).signOut();
          if (context.mounted) context.go('/login');
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'profile',
          enabled: false,
          child: Row(
            children: [
              const Icon(Icons.person_outlined, size: 18,
                  color: AppColors.kTextSecondary),
              const SizedBox(width: 10),
              Text('Profile', style: GoogleFonts.inter(fontSize: 13)),
              const Spacer(),
              Text('Coming soon',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.kTextSecondary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          enabled: false,
          child: Row(
            children: [
              const Icon(Icons.settings_outlined, size: 18,
                  color: AppColors.kTextSecondary),
              const SizedBox(width: 10),
              Text('Settings', style: GoogleFonts.inter(fontSize: 13)),
              const Spacer(),
              Text('Coming soon',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.kTextSecondary)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 18,
                  color: AppColors.kDanger),
              const SizedBox(width: 10),
              Text('Logout',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.kDanger)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.kTextSecondary),
        ],
      ),
    );
  }
}
