import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../features/auth/auth_provider.dart';
import '../features/shared/notifications_provider.dart';
import 'app_sidebar.dart';

/// Top bar displayed above the content area in the app shell.
class AppTopBar extends ConsumerWidget {
  const AppTopBar({super.key, required this.pageTitle});

  final String pageTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final profile = ref.watch(currentUserProfileProvider);
    final displayName =
        profile.valueOrNull?['displayName'] as String? ?? 'User';
    final email = profile.valueOrNull?['email'] as String? ?? '';
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final isDemo = email.endsWith('@demo.com');

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: AppColors.kCardBackground,
        border:
            Border(bottom: BorderSide(color: AppColors.kBorder, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ── Menu toggle ──────────────────────────────────────────────
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

          // ── Page title ───────────────────────────────────────────────
          Text(
            pageTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.kTextPrimary,
            ),
          ),

          const Spacer(),

          // ── Demo Mode chip ───────────────────────────────────────────
          if (isDemo) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.kWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.kWarning.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.science_rounded,
                      size: 13, color: AppColors.kWarning),
                  const SizedBox(width: 4),
                  Text(
                    'DEMO MODE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.kWarning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],

          // ── Cycle phase chip ─────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.kSuccess.withAlpha(20),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
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

          // ── Notification bell ────────────────────────────────────────
          _NotificationBell(unreadCount: unread),

          // ── Divider ──────────────────────────────────────────────────
          Container(
            height: 28,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: AppColors.kBorder,
          ),

          // ── User avatar + dropdown ───────────────────────────────────
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

  IconData _iconForType(String type) => switch (type) {
        'approval' => Icons.check_circle_rounded,
        'return' => Icons.undo_rounded,
        'shared' => Icons.share_rounded,
        'checkin' => Icons.fact_check_outlined,
        'unlock' => Icons.lock_open_rounded,
        _ => Icons.notifications_outlined,
      };

  Color _colorForType(String type) => switch (type) {
        'approval' => AppColors.kSuccess,
        'return' => AppColors.kWarning,
        'shared' => AppColors.kInfo,
        'checkin' => AppColors.kBrandPrimary,
        'unlock' => AppColors.kBrandSecondary,
        _ => AppColors.kTextSecondary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsStreamProvider);

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
                          onPressed: () async {
                            await markAllRead();
                          },
                          child: Text('Mark all read',
                              style: GoogleFonts.inter(fontSize: 12)),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.close_rounded, size: 18),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // List
                  Expanded(
                    child: notifsAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (_, __) => Center(
                        child: Text('Could not load notifications',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.kTextSecondary)),
                      ),
                      data: (notifs) => notifs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_none_rounded,
                                      size: 40,
                                      color: AppColors.kTextSecondary
                                          .withValues(alpha: 0.4)),
                                  const SizedBox(height: 8),
                                  Text('No notifications yet',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color:
                                              AppColors.kTextSecondary)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: notifs.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final n = notifs[i];
                                final typeColor = _colorForType(n.type);
                                return Container(
                                  color: n.isRead
                                      ? null
                                      : AppColors.kBrandPrimary
                                          .withValues(alpha: 0.04),
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 8),
                                    leading: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: typeColor
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                          _iconForType(n.type),
                                          size: 18,
                                          color: typeColor),
                                    ),
                                    title: Text(n.title,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: n.isRead
                                              ? FontWeight.w400
                                              : FontWeight.w700,
                                          color: AppColors.kTextPrimary,
                                        )),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 2),
                                        Text(n.body,
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: AppColors
                                                    .kTextSecondary)),
                                        const SizedBox(height: 4),
                                        Text(n.timeAgo,
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: AppColors
                                                    .kTextSecondary
                                                    .withValues(
                                                        alpha: 0.6))),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              const Icon(Icons.person_outlined,
                  size: 18, color: AppColors.kTextSecondary),
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
              const Icon(Icons.settings_outlined,
                  size: 18, color: AppColors.kTextSecondary),
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
              const Icon(Icons.logout_rounded,
                  size: 18, color: AppColors.kDanger),
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
