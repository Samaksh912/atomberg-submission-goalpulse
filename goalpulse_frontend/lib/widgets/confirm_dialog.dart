import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// Modal confirmation dialog with Cancel / Confirm buttons.
///
/// ```dart
/// final confirmed = await ConfirmDialog.show(
///   context,
///   title: 'Delete goal?',
///   message: 'This action cannot be undone.',
///   confirmLabel: 'Delete',
///   isDanger: true,
/// );
/// ```
class ConfirmDialog {
  ConfirmDialog._();

  /// Shows a modal confirmation dialog and returns `true` when the user
  /// presses the confirm button, otherwise `false`.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    VoidCallback? onConfirm,
    bool isDanger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final confirmColor =
            isDanger ? AppColors.kDanger : AppColors.kBrandPrimary;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.kTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop(true);
                          onConfirm?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmColor,
                        ),
                        child: Text(confirmLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return result ?? false;
  }
}
