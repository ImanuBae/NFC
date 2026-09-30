import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

abstract class AuthRepository {
  Stream<AuthState> get authStateChanges;
  User? get currentUser;
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<String?> getCurrentUserRole();
  Future<String?> getCurrentUserEmployeeId();
  Future<void> linkCurrentEmployee(String employeeId);
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<String?> getCurrentUserRole() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return response['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getCurrentUserEmployeeId() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select('employee_id')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return response['employee_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> linkCurrentEmployee(String employeeId) async {
    final user = currentUser;
    if (user == null) return;
    await _client
        .from('profiles')
        .update({'employee_id': employeeId})
        .eq('id', user.id);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

final currentUserEmployeeIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getCurrentUserEmployeeId();
});
