import 'package:firebase_auth/firebase_auth.dart';

/// Wraps Firebase Authentication operations used throughout GoalPulse.
///
/// Roles are stored as Firebase custom claims:
///   { "role": "employee" | "manager" | "admin" }
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Auth state ───────────────────────────────────────────────────────────

  /// Emits the current [User] (or null) whenever auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Sign-in / sign-out ───────────────────────────────────────────────────

  /// Sign in with [email] and [password].
  /// Throws [FirebaseAuthException] on failure.
  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  /// Sign the current user out.
  Future<void> signOut() => _auth.signOut();

  // ── Token helpers ─────────────────────────────────────────────────────────

  /// Returns the current user's ID token, or null if not authenticated.
  Future<String?> getCurrentIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  /// Reads the `role` custom claim from the current user's ID token result.
  /// Force-refreshes the token to guarantee fresh claims.
  Future<String?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final result = await user.getIdTokenResult(true);
    final role = result.claims?['role'];
    return role is String ? role : null;
  }

  // ── Password reset ────────────────────────────────────────────────────────

  /// Sends a password-reset email to [email].
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);
}
