import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';

/// Full-screen login page with responsive split layout.
///
/// - Desktop (≥768 px): gradient brand panel on left, form on right.
/// - Mobile: form only.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      // GoRouter redirect listener handles navigation automatically.
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } catch (_) {
      setState(() => _errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String code) => switch (code) {
    'user-not-found' => 'No account found with this email.',
    'wrong-password' || 'invalid-credential' => 'Incorrect email or password.',
    'too-many-requests' => 'Too many attempts. Please try again later.',
    'user-disabled' => 'This account has been disabled.',
    _ => 'Sign in failed. Please try again.',
  };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 768;

    return Scaffold(
      backgroundColor: AppColors.kPageBackground,
      body: isDesktop ? _desktopLayout() : _mobileLayout(),
    );
  }

  // ── Desktop: two-column split ─────────────────────────────────────────────

  Widget _desktopLayout() {
    return Row(
      children: [
        Expanded(child: _brandPanel()),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _formCard(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile: form only ────────────────────────────────────────────────────

  Widget _mobileLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: _formCard(),
      ),
    );
  }

  // ── Brand panel (left half, desktop) ─────────────────────────────────────

  Widget _brandPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.kBrandPrimary, AppColors.kBrandSecondary],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Goal / target icon
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.gps_fixed_rounded,
              size: 52,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'GoalPulse',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Align. Track. Achieve.',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white.withAlpha(210),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 48),
          // Decorative dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == 0 ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == 0 ? Colors.white : Colors.white.withAlpha(100),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form card (right half / mobile) ──────────────────────────────────────

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.kCardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Heading ─────────────────────────────────────────────────────
            Text(
              'Welcome back',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to your account',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.kTextSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // ── Email ────────────────────────────────────────────────────────
            _buildLabel('Email address'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailCtrl,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'you@company.com',
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.kTextSecondary,
                ),
              ),
              validator:
                  (v) =>
                      (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
            ),
            const SizedBox(height: 20),

            // ── Password ─────────────────────────────────────────────────────
            _buildLabel('Password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passCtrl,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.kTextSecondary,
                ),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.kTextSecondary,
                  ),
                  onPressed:
                      () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator:
                  (v) =>
                      (v == null || v.length < 6)
                          ? 'Enter your password'
                          : null,
            ),

            // ── Forgot password ───────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed:
                    _isLoading ? null : () => context.push('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ),

            // ── Sign In button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                        : const Text('Sign In'),
              ),
            ),

            // ── Error message ─────────────────────────────────────────────────
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.kDanger.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.kDanger.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.kDanger,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.kDanger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Divider ────────────────────────────────────────────────────────
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.kTextSecondary,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),

            // ── Microsoft SSO button ──────────────────────────────────────────
            /*
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _onMicrosoftSso,
                icon: _MicrosoftLogo(),
                label: const Text('Sign In with Microsoft'),
              ),
            ),
            */
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.kTextPrimary,
    ),
  );

  void _onMicrosoftSso() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SSO configured — contact Admin to enable'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}

// ── Microsoft logo (inline SVG via CustomPainter) ────────────────────────

class _MicrosoftLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _MicrosoftLogoPainter()),
    );
  }
}

class _MicrosoftLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height / 2;
    final w = size.width / 2;
    const gap = 1.5;

    // Four quadrant squares of the Microsoft logo
    final rects = [
      (Rect.fromLTWH(0, 0, w - gap / 2, h - gap / 2), const Color(0xFFF25022)),
      (
        Rect.fromLTWH(w + gap / 2, 0, w - gap / 2, h - gap / 2),
        const Color(0xFF7FBA00),
      ),
      (
        Rect.fromLTWH(0, h + gap / 2, w - gap / 2, h - gap / 2),
        const Color(0xFF00A4EF),
      ),
      (
        Rect.fromLTWH(w + gap / 2, h + gap / 2, w - gap / 2, h - gap / 2),
        const Color(0xFFFFB900),
      ),
    ];

    for (final (rect, color) in rects) {
      canvas.drawRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
