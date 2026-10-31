import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
export '../../core/api_client.dart' show AppUser;

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<String?> getCurrentUserRole();
  Future<String?> getCurrentUserEmployeeId();
  Future<void> linkCurrentEmployee(String employeeId);
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.client);
  final ApiClient client;
  @override
  Stream<AppUser?> get authStateChanges => client.authChanges;
  @override
  AppUser? get currentUser => client.currentUser;
  @override
  Future<void> signIn({required String email, required String password}) =>
      client.signIn(email, password);
  @override
  Future<void> signOut() => client.signOut();
  @override
  Future<String?> getCurrentUserRole() async {
    try {
      await client.initialize();
      return (await client.me())?.role;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getCurrentUserEmployeeId() async {
    await client.initialize();
    return (await client.me())?.employeeId;
  }

  @override
  Future<void> linkCurrentEmployee(String employeeId) async =>
      throw StateError('Employee links are assigned by Admin.');
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);
final currentRoleProvider = FutureProvider.autoDispose<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).getCurrentUserRole();
});
final currentUserEmployeeIdProvider = FutureProvider.autoDispose<String?>((
  ref,
) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).getCurrentUserEmployeeId();
});
