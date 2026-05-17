import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// A single shimmer-animated placeholder rectangle.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(1.0 + 2.0 * _ctrl.value, 0),
              colors: const [
                Color(0xFFE5E7EB),
                Color(0xFFF3F4F6),
                Color(0xFFE5E7EB),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Card-shaped skeleton with three rows of placeholder lines.
class LoadingSkeletonCard extends StatelessWidget {
  const LoadingSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kBorder.withAlpha(60)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeleton(width: 44, height: 44, borderRadius: 10),
          SizedBox(height: 20),
          LoadingSkeleton(width: 80, height: 32),
          SizedBox(height: 12),
          LoadingSkeleton(height: 14),
          SizedBox(height: 8),
          LoadingSkeleton(width: 140, height: 12),
        ],
      ),
    );
  }
}

/// Table-shaped skeleton with header and [rows] content rows.
class LoadingSkeletonTable extends StatelessWidget {
  const LoadingSkeletonTable({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kBorder.withAlpha(60)),
      ),
      child: Column(
        children: [
          // Header row
          const Row(
            children: [
              Expanded(flex: 3, child: LoadingSkeleton(height: 14)),
              SizedBox(width: 16),
              Expanded(flex: 2, child: LoadingSkeleton(height: 14)),
              SizedBox(width: 16),
              Expanded(child: LoadingSkeleton(height: 14)),
              SizedBox(width: 16),
              Expanded(child: LoadingSkeleton(height: 14)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // Content rows
          ...List.generate(
            rows,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: LoadingSkeleton(height: 14, width: 100 + (i * 20).toDouble())),
                  const SizedBox(width: 16),
                  const Expanded(flex: 2, child: LoadingSkeleton(height: 14)),
                  const SizedBox(width: 16),
                  const Expanded(child: LoadingSkeleton(height: 24, borderRadius: 999)),
                  const SizedBox(width: 16),
                  const Expanded(child: LoadingSkeleton(height: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
