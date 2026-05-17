import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../features/ai/ai_provider.dart';

/// Card widget that generates and displays an AI quarterly summary.
/// Pass [checkinId] and [quarter] — handles loading/generated states internally.
class AiSummaryWidget extends ConsumerStatefulWidget {
  const AiSummaryWidget({
    super.key,
    required this.checkinId,
    required this.quarter,
    this.initialSummary,
  });

  final String checkinId;
  final String quarter;
  /// Pre-existing summary from Firestore (if already generated).
  final String? initialSummary;

  @override
  ConsumerState<AiSummaryWidget> createState() => _AiSummaryWidgetState();
}

class _AiSummaryWidgetState extends ConsumerState<AiSummaryWidget> {
  bool _isGenerating = false;
  String? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _summary = widget.initialSummary;
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final summary =
          await ref.read(aiApiProvider).generateAiSummary(widget.checkinId);
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not generate summary. Please try again.');
    }
    setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_summary != null && _summary!.isNotEmpty) {
      return _GeneratedCard(
        summary: _summary!,
        quarter: widget.quarter,
        onRegenerate: _isGenerating ? null : _generate,
        isRegenerating: _isGenerating,
      );
    }

    return _PromptCard(
      quarter: widget.quarter,
      isGenerating: _isGenerating,
      error: _error,
      onGenerate: _generate,
    );
  }
}

// ── Prompt Card (not yet generated) ──────────────────────────────────────────

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.quarter,
    required this.isGenerating,
    required this.onGenerate,
    this.error,
  });

  final String quarter;
  final bool isGenerating;
  final VoidCallback onGenerate;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isGenerating
              ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
              : [
                  const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  const Color(0xFF7C3AED).withValues(alpha: 0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
        ),
      ),
      child: isGenerating
          ? _buildGenerating()
          : _buildPrompt(error),
    );
  }

  Widget _buildGenerating() {
    return Column(
      children: [
        const _PulsingIcon(),
        const SizedBox(height: 14),
        Text(
          'Analysing your performance data...',
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          'Powered by Google Gemini',
          style: GoogleFonts.inter(
              fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _buildPrompt(String? error) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate AI Performance Summary',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.kTextPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Get an AI-written narrative of your $quarter performance',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.kTextSecondary),
              ),
              if (error != null) ...[
                const SizedBox(height: 4),
                Text(error,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.kDanger)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: onGenerate,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: const Text('Generate'),
        ),
      ],
    );
  }
}

// ── Generated Card ────────────────────────────────────────────────────────────

class _GeneratedCard extends StatelessWidget {
  const _GeneratedCard({
    required this.summary,
    required this.quarter,
    required this.isRegenerating,
    this.onRegenerate,
  });

  final String summary;
  final String quarter;
  final bool isRegenerating;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF7C3AED), width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 16, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Text(
                'AI Summary · $quarter',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7C3AED)),
              ),
              const Spacer(),
              if (isRegenerating)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: onRegenerate,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.kTextSecondary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    textStyle: GoogleFonts.inter(fontSize: 11),
                  ),
                  child: const Text('Regenerate'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.kTextPrimary,
                height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing icon ──────────────────────────────────────────────────────────────

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl),
      child: const Icon(Icons.auto_awesome_rounded,
          size: 32, color: Colors.white),
    );
  }
}
