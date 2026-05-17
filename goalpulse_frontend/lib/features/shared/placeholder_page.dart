import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/loading_skeleton.dart';

/// Generic placeholder page wrapped in [AppShell].
///
/// Used for routes that are scaffolded but not yet implemented.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.role,
    this.showSkeletonGrid = false,
  });

  final String title;
  final UserRole role;
  final bool showSkeletonGrid;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      pageTitle: title,
      role: role,
      child: showSkeletonGrid ? _skeletonGrid() : _comingSoon(),
    );
  }

  Widget _comingSoon() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.kBrandPrimary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.construction_rounded,
                size: 30, color: AppColors.kBrandPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            '$title — Coming Soon',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.kTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This feature is under development.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonGrid() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.6,
                children: List.generate(
                    4, (_) => const LoadingSkeletonCard()),
              );
            },
          ),
          const SizedBox(height: 24),
          const LoadingSkeletonTable(rows: 5),
        ],
      ),
    );
  }
}
