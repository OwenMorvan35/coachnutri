import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CoachApiException implements Exception {
  const CoachApiException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'CoachApiException: $message';
}

class CoachResponse {
  const CoachResponse({required this.reply, this.requestId, this.meta});

  final String reply;
  final String? requestId;
  final Map<String, dynamic>? meta;
}

class CoachApi {
  CoachApi({
    http.Client? client,
    String? baseUrl,
    String? Function()? tokenProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? _resolveBaseUrl(),
       _tokenProvider = tokenProvider;

  static const Duration _timeout = Duration(seconds: 15);
  static const String _envBaseUrl = String.fromEnvironment(
    'COACH_API_BASE_URL',
  );

  final http.Client _client;
  final String _baseUrl;
  final String? Function()? _tokenProvider;

  String get baseUrl => _baseUrl;

  Future<CoachResponse> sendMessage({
    required String message,
    List<Map<String, String>> history = const <Map<String, String>>[],
    Map<String, dynamic>? profile,
  }) async {
    final uri = Uri.parse('$_baseUrl/coach');
    final payload = <String, dynamic>{'message': message};

    if (history.isNotEmpty) {
      payload['history'] = history;
    }
    if (profile != null && profile.isNotEmpty) {
      payload['profile'] = profile;
    }

    http.Response response;
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      final token = _tokenProvider?.call();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      response = await _client
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(_timeout);
    } on TimeoutException catch (error) {
      throw CoachApiException('La requête a expiré', error);
    } on http.ClientException catch (error) {
      throw CoachApiException('Impossible de contacter le serveur', error);
    } catch (error) {
      throw CoachApiException('Erreur réseau imprévue', error);
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
        // Ignore JSON parsing failure and keep default message.
      }
      throw CoachApiException(message);
    }

    try {
      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      final String? reply = decoded['reply'] as String?;
      if (reply == null || reply.isEmpty) {
        throw const CoachApiException('Réponse du coach vide');
      }
      final String? requestId = decoded['requestId'] as String?;
      final Map<String, dynamic>? meta =
          decoded['meta'] as Map<String, dynamic>?;
      return CoachResponse(reply: reply, requestId: requestId, meta: meta);
    } on CoachApiException {
      rethrow;
    } catch (error) {
      throw CoachApiException(
        'Impossible de lire la réponse du serveur',
        error,
      );
    }
  }

  void dispose() {
    _client.close();
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
