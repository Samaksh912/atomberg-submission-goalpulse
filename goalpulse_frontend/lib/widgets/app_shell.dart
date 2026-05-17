import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/theme/app_colors.dart';
import '../features/auth/auth_provider.dart';
import 'app_sidebar.dart';
import 'app_topbar.dart';

/// Shell layout that wraps every authenticated page.
///
/// ```
/// ┌──────────┬──────────────────────────────────┐
/// │          │  AppTopBar                        │
/// │ Sidebar  ├──────────────────────────────────┤
/// │          │  content (child)                  │
/// └──────────┴──────────────────────────────────┘
/// ```
///
/// On mobile (< 768 px) the sidebar becomes a drawer overlay and starts
/// collapsed by default.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.pageTitle,
    required this.role,
  });

  final Widget child;
  final String pageTitle;
  final UserRole role;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-collapse sidebar on mobile.
    final width = MediaQuery.of(context).size.width;
    if (width < 768) {
      Future.microtask(
        () => ref.read(sidebarExpandedProvider.notifier).state = false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final profile = ref.watch(currentUserProfileProvider);
    final displayName =
        profile.valueOrNull?['displayName'] as String? ?? 'User';
    final roleName = widget.role.name;

    // ── Mobile: use a Drawer for the sidebar ────────────────────────────
    if (isMobile) {
      return Scaffold(
        backgroundColor: AppColors.kPageBackground,
        drawer: Drawer(
          width: 260,
          child: AppSidebar(
            role: widget.role,
            userName: displayName,
            userRole: roleName,
          ),
        ),
        body: Column(
          children: [
            AppTopBar(pageTitle: widget.pageTitle),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    // ── Desktop: side-by-side layout ────────────────────────────────────
    return Scaffold(
      backgroundColor: AppColors.kPageBackground,
      body: Row(
        children: [
          AppSidebar(
            role: widget.role,
            userName: displayName,
            userRole: roleName,
          ),
          Expanded(
            child: Column(
              children: [
                AppTopBar(pageTitle: widget.pageTitle),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
