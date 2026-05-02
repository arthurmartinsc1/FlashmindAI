import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/secure_storage.dart';
import '../../data/db/database.dart';
import '../../data/repositories.dart';
import '../../services/sync_service.dart';

class AuthState {
  const AuthState({
    required this.bootstrapping,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.isEmailVerified,
  });

  final bool bootstrapping;
  final String? userId;
  final String? userEmail;
  final String? userName;
  final bool isEmailVerified;

  bool get isAuthenticated => userId != null;
  bool get needsEmailVerification => isAuthenticated && !isEmailVerified;

  AuthState copyWith({
    bool? bootstrapping,
    String? userId,
    String? userEmail,
    String? userName,
    bool? isEmailVerified,
    bool clearUser = false,
  }) {
    return AuthState(
      bootstrapping: bootstrapping ?? this.bootstrapping,
      userId: clearUser ? null : (userId ?? this.userId),
      userEmail: clearUser ? null : (userEmail ?? this.userEmail),
      userName: clearUser ? null : (userName ?? this.userName),
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }

  static const initial = AuthState(
    bootstrapping: true,
    userId: null,
    userEmail: null,
    userName: null,
    isEmailVerified: false,
  );
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_bootstrap);
    return AuthState.initial;
  }

  Future<void> _bootstrap() async {
    final tokens = ref.read(tokenStoreProvider);
    final access = await tokens.accessToken;
    if (access == null) {
      state = state.copyWith(bootstrapping: false);
      return;
    }
    final user = await ref.read(databaseProvider).getUser();
    if (user == null) {
      // Token exists but no local user record — treat as logged out.
      await tokens.clear();
      state = state.copyWith(bootstrapping: false);
      return;
    }
    state = AuthState(
      bootstrapping: false,
      userId: user.id,
      userEmail: user.email,
      userName: user.name,
      isEmailVerified: user.isEmailVerified,
    );
    if (state.isAuthenticated && state.isEmailVerified) {
      ref.read(syncServiceProvider).start();
    }
  }

  Future<void> login(String email, String password) async {
    final user = await ref.read(authRepoProvider).login(email, password);
    state = AuthState(
      bootstrapping: false,
      userId: user.id,
      userEmail: user.email,
      userName: user.name,
      isEmailVerified: user.isEmailVerified,
    );
    if (state.isEmailVerified) {
      ref.read(syncServiceProvider).start();
    }
  }

  Future<void> register(String name, String email, String password) async {
    final user = await ref.read(authRepoProvider).register(name, email, password);
    state = AuthState(
      bootstrapping: false,
      userId: user.id,
      userEmail: user.email,
      userName: user.name,
      isEmailVerified: user.isEmailVerified,
    );
  }

  Future<void> verifyEmail(String pin) async {
    final user = await ref.read(authRepoProvider).verifyEmail(pin);
    state = state.copyWith(isEmailVerified: user.isEmailVerified);
    if (state.isEmailVerified) {
      ref.read(syncServiceProvider).start();
    }
  }

  Future<Map<String, dynamic>> resendEmail() {
    return ref.read(authRepoProvider).resendEmail();
  }

  Future<void> logout() async {
    await ref.read(authRepoProvider).logout();
    await ref.read(databaseProvider).clearAll();
    state = state.copyWith(bootstrapping: false, clearUser: true);
  }
}

final authStateProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
