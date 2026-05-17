import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Segmented chip selector for Unit-of-Measure type.
class UomSelectorWidget extends StatelessWidget {
  const UomSelectorWidget({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  static const _options = [
    _UomOption('numeric_max', 'Higher is Better (Numeric)', Icons.trending_up,
        'A numeric target where exceeding the value is desired.'),
    _UomOption('numeric_min', 'Lower is Better (Numeric)', Icons.trending_down,
        'A numeric target where going below the value is desired.'),
    _UomOption('percent_max', 'Higher is Better (%)', Icons.percent,
        'A percentage target where exceeding the value is desired.'),
    _UomOption('percent_min', 'Lower is Better (%)', Icons.percent,
        'A percentage target where going below the value is desired.'),
    _UomOption('timeline', 'Timeline (Date)', Icons.calendar_today,
        'A date-based target — success is measured by completing before the date.'),
    _UomOption('zero', 'Zero = Success', Icons.check_circle_outline,
        'Binary outcome — 0 is success, 1 is failure (e.g. zero incidents).'),
  ];

  @override
  Widget build(BuildContext context) {
    final helper = _options
        .where((o) => o.key == selected)
        .map((o) => o.description)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Unit of Measure',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.kTextSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _options.map((o) {
            final isSelected = o.key == selected;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(o.icon,
                      size: 15,
                      color:
                          isSelected ? Colors.white : AppColors.kTextSecondary),
                  const SizedBox(width: 6),
                  Text(o.label),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(o.key),
              selectedColor: AppColors.kBrandPrimary,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color:
                      isSelected ? AppColors.kBrandPrimary : AppColors.kBorder,
                ),
              ),
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.kTextSecondary,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          }).toList(),
        ),
        if (helper != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 14, color: AppColors.kBrandPrimary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(helper,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.kBrandPrimary)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _UomOption {
  const _UomOption(this.key, this.label, this.icon, this.description);
  final String key;
  final String label;
  final IconData icon;
  final String description;
}
