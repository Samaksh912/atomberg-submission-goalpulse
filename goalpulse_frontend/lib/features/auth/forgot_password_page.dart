import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';

/// Password-reset request page with form → success state transition.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;
  String? _errorMessage;

  Future<void> _sendReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(_emailCtrl.text.trim());
      setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'An error occurred.');
    } catch (_) {
      setState(() => _errorMessage = 'Failed to send reset link.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kPageBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppColors.kCardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 32, offset: const Offset(0, 8))],
              ),
              child: _sent ? _successView() : _formView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: AppColors.kBrandPrimary.withAlpha(20), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.lock_reset_rounded, color: AppColors.kBrandPrimary, size: 28),
          ),
          const SizedBox(height: 20),
          Text('Reset your password', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.kTextPrimary)),
          const SizedBox(height: 8),
          Text('Enter the email address associated with your account and we\'ll send you a reset link.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.kTextSecondary)),
          const SizedBox(height: 28),
          Text('Email address', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.kTextPrimary)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'you@company.com', prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.kTextSecondary)),
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.kDanger)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendReset,
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Send Reset Link'),
            ),
          ),
          const SizedBox(height: 20),
          _backToLoginLink(),
        ],
      ),
    );
  }

  Widget _successView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: AppColors.kSuccess.withAlpha(20), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: AppColors.kSuccess, size: 40),
        ),
        const SizedBox(height: 24),
        Text('Check your email', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.kTextPrimary), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text('Reset link sent to', style: GoogleFonts.inter(fontSize: 14, color: AppColors.kTextSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(_emailCtrl.text.trim(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.kTextPrimary), textAlign: TextAlign.center),
        const SizedBox(height: 28),
        _backToLoginLink(),
      ],
    );
  }

  Widget _backToLoginLink() => Center(
    child: TextButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back_rounded, size: 16),
      label: const Text('Back to Sign In'),
    ),
  );

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }
}
