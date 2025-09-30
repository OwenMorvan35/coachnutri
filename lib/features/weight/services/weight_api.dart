import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/weight_models.dart';

class WeightApiException implements Exception {
  const WeightApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => 'WeightApiException($statusCode): $message';
}

class WeightNlpResponse {
  const WeightNlpResponse({required this.message, required this.entry});

  final String message;
  final WeightEntry entry;
}

class WeightApi {
  WeightApi({String? baseUrl, String? Function()? tokenProvider})
      : _baseUrl = baseUrl ?? _resolveBaseUrl(),
        _tokenProvider = tokenProvider,
        _client = http.Client();

  final String _baseUrl;
  final String? Function()? _tokenProvider;
  final http.Client _client;

  Future<WeightDataset> fetchRange({
    required WeightRange range,
    WeightAggregate aggregate = WeightAggregate.latest,
  }) async {
    final params = {
      'range': range.queryValue,
      'aggregate': aggregate.queryValue,
    };
    final uri = Uri.parse('$_baseUrl/weights').replace(queryParameters: params);
    final response = await _send(() => _client.get(uri, headers: _headers()));
    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return WeightDataset.fromJson(data);
  }

  Future<WeightEntry> createEntry({
    required double weightKg,
    required DateTime date,
    String? note,
  }) async {
    final uri = Uri.parse('$_baseUrl/weights');
    final payload = <String, dynamic>{
      'weightKg': double.parse(weightKg.toStringAsFixed(2)),
      'date': date.toUtc().toIso8601String(),
    };
    if (note != null && note.trim().isNotEmpty) payload['note'] = note.trim();
    final response = await _send(
      () => _client.post(uri, headers: _headers(), body: jsonEncode(payload)),
    );
    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    final entryJson = data['entry'] as Map<String, dynamic>?;
    if (entryJson == null) {
      throw const WeightApiException('Réponse du serveur incomplète');
    }
    return WeightEntry.fromJson(entryJson);
  }

  Future<WeightNlpResponse> logViaNlp(String text, {String? note}) async {
    final uri = Uri.parse('$_baseUrl/nlp/weights/parse-and-log');
    final payload = <String, dynamic>{'text': text};
    if (note != null && note.trim().isNotEmpty) payload['note'] = note.trim();
    final response = await _send(
      () => _client.post(uri, headers: _headers(), body: jsonEncode(payload)),
    );
    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    final entryJson = data['entry'] as Map<String, dynamic>?;
    final message = (data['message'] as String? ?? '').trim();
    if (entryJson == null || message.isEmpty) {
      throw const WeightApiException('Réponse NLP invalide');
    }
    return WeightNlpResponse(message: message, entry: WeightEntry.fromJson(entryJson));
  }

  Map<String, String> _headers() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      final message = _extractError(response.body) ?? 'Erreur ${response.statusCode}';
      throw WeightApiException(message, response.statusCode);
    } on WeightApiException {
      rethrow;
    } catch (error) {
      throw WeightApiException('Erreur réseau inattendue: $error');
    }
  }

  String? _extractError(String body) {
    try {
      final Map<String, dynamic> json = jsonDecode(body) as Map<String, dynamic>;
      final err = json['error'];
      if (err is Map<String, dynamic>) {
        final message = err['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  void dispose() => _client.close();
}

String _resolveBaseUrl() {
  const envBase = String.fromEnvironment('COACH_API_BASE_URL');
  if (envBase.isNotEmpty) return envBase;
  if (kIsWeb) return 'http://localhost:5001';
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
