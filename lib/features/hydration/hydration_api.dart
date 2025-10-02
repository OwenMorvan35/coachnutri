import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HydrationApiException implements Exception {
  const HydrationApiException(
    this.message, {
      this.statusCode,
      this.code,
      this.retryAfterMs,
      this.nextAvailableAt,
      this.hydration,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final int? retryAfterMs;
  final DateTime? nextAvailableAt;
  final HydrationStateDto? hydration;

  @override
  String toString() =>
      'HydrationApiException(code: $code, status: $statusCode, message: $message)';
}

class HydrationStateDto {
  HydrationStateDto({
    required this.id,
    required this.userId,
    required this.consumedMl,
    required this.dailyGoalMl,
    required this.progress,
    required this.hydrationPercent,
    required this.lastResetAt,
    required this.createdAt,
    required this.updatedAt,
    this.lastIntakeAt,
    this.nextAvailableAt,
    required this.cooldownMs,
    this.cooldownRemainingMs,
  });

  final String id;
  final String userId;
  final int consumedMl;
  final int dailyGoalMl;
  final double progress;
  final double hydrationPercent;
  final DateTime lastResetAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastIntakeAt;
  final DateTime? nextAvailableAt;
  final int cooldownMs;
  final int? cooldownRemainingMs;

  factory HydrationStateDto.fromJson(Map<String, dynamic> json) {
    return HydrationStateDto(
      id: json['id'] as String,
      userId: json['userId'] as String,
      consumedMl: (json['consumedMl'] as num).toInt(),
      dailyGoalMl: (json['dailyGoalMl'] as num).toInt(),
      progress: (json['progress'] as num).toDouble(),
      hydrationPercent: (json['hydrationPercent'] as num).toDouble(),
      lastResetAt: DateTime.parse(json['lastResetAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastIntakeAt: (json['lastIntakeAt'] as String?) != null
          ? DateTime.parse(json['lastIntakeAt'] as String)
          : null,
      nextAvailableAt: (json['nextAvailableAt'] as String?) != null
          ? DateTime.parse(json['nextAvailableAt'] as String)
          : null,
      cooldownMs: (json['cooldownMs'] as num?)?.toInt() ?? 0,
      cooldownRemainingMs: (json['cooldownRemainingMs'] as num?)?.toInt(),
    );
  }
}

class HydrationApi {
  HydrationApi({String? baseUrl, String? Function()? tokenProvider})
      : _baseUrl = baseUrl ?? _resolveBaseUrl(),
        _tokenProvider = tokenProvider,
        _client = http.Client();

  final http.Client _client;
  final String _baseUrl;
  final String? Function()? _tokenProvider;

  static const Duration _timeout = Duration(seconds: 15);
  static const String _envBaseUrl = String.fromEnvironment('COACH_API_BASE_URL');

  Future<HydrationStateDto> fetchState() async {
    final response = await _send(() => _client
        .get(
          Uri.parse('$_baseUrl/hydration'),
          headers: _headers(),
        )
        .timeout(_timeout));

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final hydration = payload['hydration'];
    if (hydration is! Map<String, dynamic>) {
      throw const HydrationApiException('Réponse hydratation invalide');
    }
    return HydrationStateDto.fromJson(hydration);
  }

  Future<HydrationStateDto> addIntake(int amountMl) async {
    final response = await _send(() => _client
        .post(
          Uri.parse('$_baseUrl/hydration/intake'),
          headers: _headers(),
          body: jsonEncode({'amount': amountMl}),
        )
        .timeout(_timeout));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final hydration = payload['hydration'];
    if (hydration is! Map<String, dynamic>) {
      throw const HydrationApiException('Réponse hydratation invalide');
    }
    return HydrationStateDto.fromJson(hydration);
  }

  Future<HydrationStateDto> updateGoal(int dailyGoalMl) async {
    final response = await _send(() => _client
        .patch(
          Uri.parse('$_baseUrl/hydration'),
          headers: _headers(),
          body: jsonEncode({'dailyGoalMl': dailyGoalMl}),
        )
        .timeout(_timeout));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final hydration = payload['hydration'];
    if (hydration is! Map<String, dynamic>) {
      throw const HydrationApiException('Réponse hydratation invalide');
    }
    return HydrationStateDto.fromJson(hydration);
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
    } on HydrationApiException {
      rethrow;
    } on http.ClientException catch (error) {
      throw HydrationApiException('Erreur réseau: $error');
    } catch (error) {
      throw HydrationApiException('Erreur inattendue: $error');
    }
  }

  HydrationApiException _toException(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      final message = (error?['message'] as String?) ?? 'Erreur ${response.statusCode}';
      final code = error?['code'] as String?;
      final retryAfterMs = (error?['retryAfterMs'] as num?)?.toInt();
      final nextAvailableAtStr = error?['nextAvailableAt'] as String?;
      HydrationStateDto? hydration;
      final hydrationJson = decoded['hydration'];
      if (hydrationJson is Map<String, dynamic>) {
        hydration = HydrationStateDto.fromJson(hydrationJson);
      }
      return HydrationApiException(
        message,
        statusCode: response.statusCode,
        code: code,
        retryAfterMs: retryAfterMs,
        nextAvailableAt:
            nextAvailableAtStr != null ? DateTime.parse(nextAvailableAtStr) : null,
        hydration: hydration,
      );
    } catch (_) {
      return HydrationApiException(
        'Erreur ${response.statusCode}',
        statusCode: response.statusCode,
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
