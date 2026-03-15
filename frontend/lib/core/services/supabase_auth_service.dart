import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SessionReader = Session? Function();
typedef SessionRefresher = Future<AuthResponse> Function(String? refreshToken);
typedef SignOutAction = Future<void> Function();

class SupabaseAuthService {
  SupabaseAuthService._({
    SupabaseClient? client,
    SessionReader? sessionReader,
    SessionRefresher? sessionRefresher,
    SignOutAction? signOutAction,
  })  : _client = client,
        _sessionReader = sessionReader ??
            (() => (client ?? Supabase.instance.client).auth.currentSession),
        _sessionRefresher = sessionRefresher ??
            ((refreshToken) =>
                (client ?? Supabase.instance.client).auth.refreshSession(
                      refreshToken,
                    )),
        _signOutAction = signOutAction ??
            (() => (client ?? Supabase.instance.client).auth.signOut());

  static final SupabaseAuthService instance = SupabaseAuthService._();

  @visibleForTesting
  factory SupabaseAuthService.test({
    required SessionReader sessionReader,
    required SessionRefresher sessionRefresher,
    SignOutAction? signOutAction,
  }) {
    return SupabaseAuthService._(
      sessionReader: sessionReader,
      sessionRefresher: sessionRefresher,
      signOutAction: signOutAction,
    );
  }

  final SupabaseClient? _client;
  final SessionReader _sessionReader;
  final SessionRefresher _sessionRefresher;
  final SignOutAction _signOutAction;

  SupabaseClient get _requiredClient => _client ?? Supabase.instance.client;

  Future<void> sendOtp(String email) async {
    await _requiredClient.auth.signInWithOtp(email: email.trim());
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    required String otp,
  }) async {
    return _requiredClient.auth.verifyOTP(
      email: email.trim(),
      token: otp.trim(),
      type: OtpType.magiclink,
    );
  }

  Future<AuthResponse> signInAnonymously() async {
    return _requiredClient.auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _signOutAction();
  }

  Session? getCurrentSession() {
    return _sessionReader();
  }

  bool get hasAuthenticatedSession {
    final session = getCurrentSession();
    final email = session?.user.email?.trim() ?? '';
    return session != null && email.isNotEmpty;
  }

  Future<Session?> ensureActiveSession({bool forceRefresh = false}) async {
    final session = getCurrentSession();
    if (session == null) {
      return null;
    }
    if (!forceRefresh && !session.isExpired) {
      return session;
    }

    final refreshToken = session.refreshToken?.trim() ?? '';
    if (refreshToken.isEmpty) {
      await signOut();
      return null;
    }

    try {
      final response = await _sessionRefresher(refreshToken);
      return response.session ?? getCurrentSession();
    } on AuthRetryableFetchException {
      rethrow;
    } on AuthException {
      return getCurrentSession();
    }
  }

  Future<String?> getValidAccessToken({bool forceRefresh = false}) async {
    final session = await ensureActiveSession(forceRefresh: forceRefresh);
    final accessToken = session?.accessToken.trim() ?? '';
    if (accessToken.isEmpty) {
      return null;
    }
    return accessToken;
  }

  String? getCurrentUserId() {
    if (!hasAuthenticatedSession) return null;
    return _requiredClient.auth.currentUser?.id;
  }

  Stream<AuthState> get authStateChanges {
    return _requiredClient.auth.onAuthStateChange;
  }
}
