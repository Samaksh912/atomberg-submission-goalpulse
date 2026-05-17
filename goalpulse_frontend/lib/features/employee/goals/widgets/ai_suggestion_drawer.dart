import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../features/ai/ai_provider.dart';
import '../../../../features/auth/auth_provider.dart';

/// Callback when the user picks an AI suggestion — fills parent GoalCard.
typedef OnSuggestionApplied = void Function(GoalSuggestion suggestion);

/// Right-side slide-over drawer (480 px) for AI goal suggestions.
class AiSuggestionDrawer extends ConsumerStatefulWidget {
  const AiSuggestionDrawer({
    super.key,
    required this.thrustArea,
    required this.existingTitles,
    required this.onApply,
  });

  final String thrustArea;
  final List<String> existingTitles;
  final OnSuggestionApplied onApply;

  /// Open the drawer as a modal end-drawer overlay.
  static Future<void> show(
    BuildContext context, {
    required String thrustArea,
    required List<String> existingTitles,
    required OnSuggestionApplied onApply,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AI Suggestions',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.centerRight,
        child: AiSuggestionDrawer(
          thrustArea: thrustArea,
          existingTitles: existingTitles,
          onApply: onApply,
        ),
      ),
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  @override
  ConsumerState<AiSuggestionDrawer> createState() =>
      _AiSuggestionDrawerState();
}

class _AiSuggestionDrawerState extends ConsumerState<AiSuggestionDrawer> {
  _DrawerState _state = _DrawerState.loading;
  List<GoalSuggestion> _suggestions = [];
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = _DrawerState.loading;
      _errorMsg = null;
    });
    try {
      final user = ref.read(currentUserProfileProvider).valueOrNull;
      final suggestions = await ref.read(aiApiProvider).suggestGoals(
            role: user?['role'] as String? ?? 'Employee',
            department: user?['department'] as String? ?? '',
            thrustArea: widget.thrustArea,
            existingTitles: widget.existingTitles,
          );
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _state = _DrawerState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = '$e';
        _state = _DrawerState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 480,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.kCardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(-8, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                '✨ AI Goal Suggestions',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Powered by Gemini · Thrust Area: ${widget.thrustArea}',
            style: GoogleFonts.inter(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return switch (_state) {
      _DrawerState.loading => _buildLoading(),
      _DrawerState.error => _buildError(),
      _DrawerState.loaded => _buildSuggestions(),
    };
  }

  Widget _buildLoading() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _PulsingSparkle(),
        const SizedBox(height: 20),
        Text(
          'Asking Gemini AI for\ngoal suggestions...',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.kTextSecondary,
              height: 1.5),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.kDanger),
          const SizedBox(height: 16),
          Text(
            'Could not load suggestions.\nPlease try again.'
            '${_errorMsg != null ? '\n$_errorMsg' : ''}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.kTextSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kBrandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Tap "Use This Goal" to fill your goal card with the suggestion.',
          style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.kTextSecondary),
        ),
        const SizedBox(height: 12),
        ..._suggestions.map((s) => _SuggestionCard(
              suggestion: s,
              onApply: () {
                widget.onApply(s);
                Navigator.of(context).pop();
              },
            )),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 14),
          label: const Text('Regenerate suggestions'),
          style: TextButton.styleFrom(
              foregroundColor: AppColors.kTextSecondary,
              textStyle: GoogleFonts.inter(fontSize: 12)),
        ),
      ],
    );
  }
}

// ── Suggestion Card ───────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.onApply,
  });
  final GoalSuggestion suggestion;
  final VoidCallback onApply;

  String get _uomLabel => switch (suggestion.uomType) {
        'numeric_max' => '↑ Numeric',
        'numeric_min' => '↓ Numeric',
        'percent_max' => '↑ %',
        'percent_min' => '↓ %',
        'timeline' => 'Timeline',
        'zero' => 'Zero',
        _ => suggestion.uomType,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kNeutral100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.kBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.title,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.kTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            suggestion.description,
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.kTextSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              _badge(_uomLabel, const Color(0xFF4F46E5)),
              _badge('Target: ${suggestion.recommendedTarget}',
                  AppColors.kSuccess),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '💡 ${suggestion.rationale}',
            style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.kTextSecondary,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              child: const Text('Use This Goal'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
      );
}

// ── Pulsing Sparkle Animation ─────────────────────────────────────────────────

class _PulsingSparkle extends StatefulWidget {
  const _PulsingSparkle();

  @override
  State<_PulsingSparkle> createState() => _PulsingSparkleState();
}

class _PulsingSparkleState extends State<_PulsingSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
              blurRadius: 20,
            ),
          ],
        ),
        child: const Icon(Icons.auto_awesome_rounded,
            color: Colors.white, size: 32),
      ),
    );
  }
}

// ── State enum ────────────────────────────────────────────────────────────────

enum _DrawerState { loading, loaded, error }
