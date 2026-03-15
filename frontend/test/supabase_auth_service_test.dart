import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('ensureActiveSession 在会话未过期时直接复用当前会话', () async {
    final session = _buildSession(
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    );
    var refreshed = false;
    final service = SupabaseAuthService.test(
      sessionReader: () => session,
      sessionRefresher: (_) async {
        refreshed = true;
        return AuthResponse(session: session);
      },
    );

    final resolved = await service.ensureActiveSession();

    expect(resolved, same(session));
    expect(refreshed, isFalse);
  });

  test('ensureActiveSession 在会话已过期时会刷新 access token', () async {
    var currentSession = _buildSession(
      expiresAt: DateTime.now().subtract(const Duration(minutes: 2)),
      refreshToken: 'refresh-old',
    );
    final refreshedSession = _buildSession(
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      refreshToken: 'refresh-new',
    );
    var refreshedWith = '';
    final service = SupabaseAuthService.test(
      sessionReader: () => currentSession,
      sessionRefresher: (refreshToken) async {
        refreshedWith = refreshToken ?? '';
        currentSession = refreshedSession;
        return AuthResponse(session: refreshedSession);
      },
    );

    final resolved = await service.ensureActiveSession();

    expect(refreshedWith, 'refresh-old');
    expect(resolved, same(refreshedSession));
    expect(await service.getValidAccessToken(), refreshedSession.accessToken);
  });

  test('ensureActiveSession 在缺少 refresh token 时会退出当前会话', () async {
    var signedOut = false;
    final service = SupabaseAuthService.test(
      sessionReader: () => _buildSession(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        refreshToken: '',
      ),
      sessionRefresher: (_) async {
        throw StateError('不应尝试刷新');
      },
      signOutAction: () async {
        signedOut = true;
      },
    );

    final resolved = await service.ensureActiveSession();

    expect(resolved, isNull);
    expect(signedOut, isTrue);
  });
}

Session _buildSession({
  required DateTime expiresAt,
  String refreshToken = 'refresh-token',
}) {
  final exp = expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000;
  return Session(
    accessToken: _jwtWithExp(exp),
    expiresIn: expiresAt.difference(DateTime.now()).inSeconds,
    refreshToken: refreshToken,
    tokenType: 'bearer',
    user: const User(
      id: 'user-1',
      appMetadata: <String, dynamic>{},
      userMetadata: <String, dynamic>{},
      aud: 'authenticated',
      email: 'tester@example.com',
      createdAt: '2026-03-14T00:00:00Z',
    ),
  );
}

String _jwtWithExp(int exp) {
  String encode(Map<String, dynamic> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({
        'exp': exp
      })}.signature';
}
