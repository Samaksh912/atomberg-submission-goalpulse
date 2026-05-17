import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/auth_service.dart';
import '../../core/network/api_client.dart';

// ── Service provider ──────────────────────────────────────────────────────

/// Singleton [AuthService] — injected everywhere via Riverpod.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ── Auth state ────────────────────────────────────────────────────────────

/// Emits [User?] in real-time from Firebase auth state stream.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ── Role ──────────────────────────────────────────────────────────────────

/// Resolves the role custom claim for the currently signed-in user.
/// Returns null when signed out.
final userRoleProvider = FutureProvider<String?>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;
  return ref.read(authServiceProvider).getUserRole();
});

// ── User profile ──────────────────────────────────────────────────────────

/// Calls POST /auth/verify and returns the server-side user profile map.
/// Returns null when not authenticated.
final currentUserProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;

  final token = await ref.read(authServiceProvider).getCurrentIdToken();
  if (token == null) return null;

  try {
    final api = ref.read(apiClientProvider);
    final response = await api.post(
      '/auth/verify',
      options: ApiClient.bearerOptions(token),
    );
    return response.data as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
});
