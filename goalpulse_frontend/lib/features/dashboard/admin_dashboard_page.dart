import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../shared/placeholder_page.dart';

/// Admin dashboard — skeleton grid inside AppShell.
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Dashboard',
      role: UserRole.admin,
      showSkeletonGrid: true,
    );
  }
}
