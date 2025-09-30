import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/models/auth_session.dart';
import 'logger.dart';

class SessionStorage {
  static const String _kToken = 'cn_auth_token';
  static const String _kUser = 'cn_auth_user';

  Future<AuthSession?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kToken);
      final userRaw = prefs.getString(_kUser);
      if (token == null || token.isEmpty || userRaw == null || userRaw.isEmpty) {
        return null;
      }
      final Map<String, dynamic> m = jsonDecode(userRaw) as Map<String, dynamic>;
      final user = AuthUser(
        id: (m['id'] as String? ?? '').trim(),
        email: (m['email'] as String? ?? '').trim(),
        name: m['name'] as String?,
        displayName: m['displayName'] as String?,
        avatarUrl: m['avatarUrl'] as String?,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: m['updatedAt'] != null
            ? DateTime.tryParse(m['updatedAt'] as String)
            : null,
      );
      if (user.id.isEmpty || user.email.isEmpty) {
        return null;
      }
      Logger.i('SESSION_STORAGE', 'Session restored from cache');
      return AuthSession(token: token, user: user);
    } catch (error, stackTrace) {
      Logger.e('SESSION_STORAGE', 'Failed to load session', error, stackTrace);
      return null;
    }
  }

  Future<void> save(AuthSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userMap = <String, dynamic>{
        'id': session.user.id,
        'email': session.user.email,
        if (session.user.name != null) 'name': session.user.name,
        if (session.user.displayName != null) 'displayName': session.user.displayName,
        if (session.user.avatarUrl != null) 'avatarUrl': session.user.avatarUrl,
        'createdAt': session.user.createdAt.toIso8601String(),
        if (session.user.updatedAt != null) 'updatedAt': session.user.updatedAt!.toIso8601String(),
      };
      await prefs.setString(_kToken, session.token);
      await prefs.setString(_kUser, jsonEncode(userMap));
      Logger.i('SESSION_STORAGE', 'Session saved to cache');
    } catch (error, stackTrace) {
      Logger.e('SESSION_STORAGE', 'Failed to save session', error, stackTrace);
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kToken);
      await prefs.remove(_kUser);
      Logger.i('SESSION_STORAGE', 'Session cleared from cache');
    } catch (error, stackTrace) {
      Logger.e('SESSION_STORAGE', 'Failed to clear session', error, stackTrace);
    }
  }
}
