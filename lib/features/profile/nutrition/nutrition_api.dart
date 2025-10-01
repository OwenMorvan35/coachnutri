import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'nutrition_profile.dart';

class NutritionApiException implements Exception {
  const NutritionApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => 'NutritionApiException($statusCode): $message';
}

class NutritionApi {
  NutritionApi({String? baseUrl, String? Function()? tokenProvider})
      : _baseUrl = baseUrl ?? _resolveBaseUrl(),
        _tokenProvider = tokenProvider,
        _client = http.Client();

  final http.Client _client;
  final String _baseUrl;
  final String? Function()? _tokenProvider;

  static const Duration _timeout = Duration(seconds: 20);
  static const String _envBaseUrl = String.fromEnvironment('COACH_API_BASE_URL');

  Future<NutritionProfile> fetchProfile() async {
    final response = await _send(
      () => _client
          .get(
            Uri.parse('$_baseUrl/users/me/nutrition'),
            headers: _headers(),
          )
          .timeout(_timeout),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final profileJson = decoded['profile'] as Map<String, dynamic>?;
    if (profileJson == null) {
      throw const NutritionApiException('Profil nutrition indisponible');
    }
    return NutritionProfile.fromJson(profileJson);
  }

  Future<NutritionProfile> updateProfile(Map<String, dynamic> payload) async {
    final response = await _send(
      () => _client
          .put(
            Uri.parse('$_baseUrl/users/me/nutrition'),
            headers: _headers(),
            body: jsonEncode(payload),
          )
          .timeout(_timeout),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final profileJson = decoded['profile'] as Map<String, dynamic>?;
    if (profileJson == null) {
      throw const NutritionApiException('Réponse serveur invalide');
    }
    return NutritionProfile.fromJson(profileJson);
  }

  Map<String, String> _headers() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> _send(Future<http.Response> Function() operation) async {
    try {
      final response = await operation();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw _toException(response);
    } on NutritionApiException {
      rethrow;
    } on http.ClientException catch (error) {
      throw NutritionApiException('Erreur réseau: $error');
    } catch (error) {
      throw NutritionApiException('Erreur inattendue: $error');
    }
  }

  NutritionApiException _toException(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      final message = (error?['message'] as String?) ?? 'Erreur ${response.statusCode}';
      return NutritionApiException(message, response.statusCode);
    } catch (_) {
      return NutritionApiException('Erreur ${response.statusCode}', response.statusCode);
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
