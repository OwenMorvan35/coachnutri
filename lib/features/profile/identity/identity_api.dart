import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'identity_profile.dart';

class IdentityApiException implements Exception {
  const IdentityApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => 'IdentityApiException($statusCode): $message';
}

class IdentityApi {
  IdentityApi({String? baseUrl, String? Function()? tokenProvider})
      : _baseUrl = baseUrl ?? _resolveBaseUrl(),
        _tokenProvider = tokenProvider,
        _client = http.Client();

  final http.Client _client;
  final String _baseUrl;
  final String? Function()? _tokenProvider;

  static const Duration _timeout = Duration(seconds: 20);
  static const String _envBaseUrl = String.fromEnvironment('COACH_API_BASE_URL');

  Future<IdentityProfile> fetchProfile() async {
    final response = await _send(
      () => _client
          .get(Uri.parse('$_baseUrl/users/me'), headers: _jsonHeaders())
          .timeout(_timeout),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final user = decoded['user'] as Map<String, dynamic>?;
    if (user == null) {
      throw const IdentityApiException('Réponse profil invalide');
    }
    return _parseProfile(user);
  }

  Future<IdentityProfile> updateProfile({String? displayName, String? name}) async {
    final payload = <String, dynamic>{};
    if (displayName != null) payload['displayName'] = displayName;
    if (name != null) payload['name'] = name;
    final response = await _send(
      () => _client
          .put(
            Uri.parse('$_baseUrl/users/me'),
            headers: _jsonHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(_timeout),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final user = decoded['user'] as Map<String, dynamic>?;
    if (user == null) {
      throw const IdentityApiException('Réponse profil invalide');
    }
    return _parseProfile(user);
  }

  Future<IdentityProfile> uploadAvatar({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/me/avatar');
    final request = http.MultipartRequest('POST', uri);
    final token = _tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    MediaType mediaType;
    try {
      mediaType = MediaType.parse(mimeType);
    } catch (_) {
      mediaType = MediaType('image', 'jpeg');
    }

    final safeName = (filename.isNotEmpty ? filename : 'avatar.jpg');

    request.files.add(
      http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: safeName,
        contentType: mediaType,
      ),
    );

    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(_timeout);
    } on TimeoutException {
      throw const IdentityApiException('Téléversement trop long');
    }

    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _toException(response);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final user = decoded['user'] as Map<String, dynamic>?;
    if (user == null) {
      throw const IdentityApiException('Réponse avatar invalide');
    }
    return _parseProfile(user);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _send(
      () => _client
          .post(
            Uri.parse('$_baseUrl/users/me/password'),
            headers: _jsonHeaders(),
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(_timeout),
    );

    if (response.statusCode != 204) {
      throw _toException(response);
    }
  }

  void dispose() {
    _client.close();
  }

  Map<String, String> _jsonHeaders() {
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
    } on IdentityApiException {
      rethrow;
    } on TimeoutException {
      throw const IdentityApiException('La requête a expiré');
    } catch (error) {
      throw IdentityApiException('Erreur réseau inattendue: $error');
    }
  }

  IdentityProfile _parseProfile(Map<String, dynamic> json) {
    final profile = IdentityProfile.fromJson(json);
    final resolvedAvatar = profile.avatarUrl != null
        ? _resolveUri(profile.avatarUrl!)
        : null;
    return profile.copyWith(avatarUrl: resolvedAvatar);
  }

  IdentityApiException _toException(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      final message = (error?['message'] as String?) ?? 'Erreur ${response.statusCode}';
      return IdentityApiException(message, response.statusCode);
    } catch (_) {
      return IdentityApiException('Erreur ${response.statusCode}', response.statusCode);
    }
  }

  String? _resolveUri(String value) {
    final base = Uri.parse(_baseUrl);
    return base.resolve(value).toString();
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
