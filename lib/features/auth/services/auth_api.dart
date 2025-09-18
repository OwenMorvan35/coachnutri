import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_session.dart';

class AuthApiException implements Exception {
  const AuthApiException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'AuthApiException: $message';
}

class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? _resolveBaseUrl();

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 15);
  static const String _envBaseUrl = String.fromEnvironment(
    'COACH_API_BASE_URL',
  );

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _authenticate(
      '$_baseUrl/auth/login',
      email: email,
      password: password,
    );
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    String? name,
  }) async {
    return _authenticate(
      '$_baseUrl/auth/register',
      email: email,
      password: password,
      name: name,
    );
  }

  void dispose() {
    _client.close();
  }

  Future<AuthSession> _authenticate(
    String url, {
    required String email,
    required String password,
    String? name,
  }) async {
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(url),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              if (name != null && name.isNotEmpty) 'name': name,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException catch (error) {
      throw AuthApiException('La requête a expiré', error);
    } on http.ClientException catch (error) {
      throw AuthApiException('Impossible de contacter le serveur', error);
    } catch (error) {
      throw AuthApiException('Erreur réseau imprévue', error);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Réponse invalide du serveur (${response.statusCode})';
      try {
        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        final Map<String, dynamic>? errorPayload =
            body['error'] as Map<String, dynamic>?;
        final String? serverMessage = errorPayload?['message'] as String?;
        if (serverMessage != null && serverMessage.isNotEmpty) {
          message = serverMessage;
        }
      } catch (_) {
        // Ignore JSON parsing errors.
      }
      throw AuthApiException(message);
    }

    try {
      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      final String? token = decoded['token'] as String?;
      final Map<String, dynamic>? userRaw =
          decoded['user'] as Map<String, dynamic>?;

      if (token == null || token.isEmpty || userRaw == null) {
        throw const AuthApiException('Réponse du serveur invalide');
      }

      final user = AuthUser(
        id: userRaw['id'] as String,
        email: userRaw['email'] as String,
        name: userRaw['name'] as String?,
        createdAt: DateTime.parse(userRaw['createdAt'] as String),
        updatedAt: userRaw['updatedAt'] != null
            ? DateTime.tryParse(userRaw['updatedAt'] as String)
            : null,
      );

      return AuthSession(token: token, user: user);
    } on AuthApiException {
      rethrow;
    } catch (error) {
      throw AuthApiException('Impossible de lire la réponse du serveur', error);
    }
  }

  static String _resolveBaseUrl() {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:5001';
    }
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return 'http://10.0.2.2:5001';
        default:
          return 'http://localhost:5001';
      }
    } catch (_) {
      return 'http://localhost:5001';
    }
  }
}
