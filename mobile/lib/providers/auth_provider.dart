import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

// ---------------------------------------------------------------------------
// Auth state — ChangeNotifier so GoRouter can refreshListenable on it.
// ---------------------------------------------------------------------------
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier() {
    _supabase.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
}

final authStateProvider = ChangeNotifierProvider<AuthStateNotifier>(
  (_) => AuthStateNotifier(),
);

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider); // rebuild when auth changes
  return _supabase.auth.currentUser;
});

// ---------------------------------------------------------------------------
// Sign-in helpers
// ---------------------------------------------------------------------------

/// Resolve username → email via Supabase RPC, then sign in.
Future<AuthResponse> signInWithUsername(String username, String password) async {
  final email = await _supabase
      .rpc('get_email_by_username', params: {'p_username': username.trim().toLowerCase()})
      .single() as String?;

  if (email == null || email.isEmpty) {
    throw const AuthException('Username not found.');
  }
  return _supabase.auth.signInWithPassword(email: email, password: password);
}

/// Sign up with username, email, and password.
Future<AuthResponse> signUp({
  required String username,
  required String email,
  required String password,
}) async {
  return _supabase.auth.signUp(
    email: email.trim(),
    password: password,
    data: {
      'username': username.trim().toLowerCase(),
      'display_username': username.trim(),
    },
  );
}

Future<void> signOut() => _supabase.auth.signOut();
