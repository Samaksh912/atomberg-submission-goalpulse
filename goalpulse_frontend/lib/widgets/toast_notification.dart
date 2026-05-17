import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// Global toast notification system with colour-coded left-border accent.
///
/// ```dart
/// ToastNotification.showSuccess(context, 'Goal saved successfully');
/// ToastNotification.showError(context, 'Failed to load data');
/// ToastNotification.showInfo(context, 'New check-in window open');
/// ```
class ToastNotification {
  ToastNotification._();

  static void showSuccess(BuildContext context, String message) =>
      _show(context, message, AppColors.kSuccess, Icons.check_circle_rounded);

  static void showError(BuildContext context, String message) =>
      _show(context, message, AppColors.kDanger, Icons.error_rounded);

  static void showInfo(BuildContext context, String message) =>
      _show(context, message, AppColors.kInfo, Icons.info_rounded);

  static void _show(
    BuildContext context,
    String message,
    Color accentColor,
    IconData icon,
  ) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _ToastOverlay(
        message: message,
        accentColor: accentColor,
        icon: icon,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.message,
    required this.accentColor,
    required this.icon,
    required this.onDismiss,
  });

  final String message;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onDismiss;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(_ctrl);

    _ctrl.forward();

    // Auto-dismiss after 4 seconds.
    Future.delayed(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380, minWidth: 280),
              decoration: BoxDecoration(
                color: AppColors.kCardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(color: widget.accentColor, width: 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: widget.accentColor, size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.kTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.kTextSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
