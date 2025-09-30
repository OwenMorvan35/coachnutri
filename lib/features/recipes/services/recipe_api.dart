import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';

class RecipeApi {
  RecipeApi({String? baseUrl, String? Function()? tokenProvider})
      : _baseUrl = baseUrl ?? _resolveBaseUrl(),
        _tokenProvider = tokenProvider,
        _client = http.Client();

  final String _baseUrl;
  final String? Function()? _tokenProvider;
  final http.Client _client;

  Future<List<Recipe>> fetchAll() async {
    final uri = Uri.parse('$_baseUrl/recipes');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _tokenProvider?.call();
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    final resp = await _client.get(uri, headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Failed to fetch recipes (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final List<dynamic> arr = (decoded['recipes'] as List?) ?? const [];
    return arr.map((e) => _fromBackend(e as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<Recipe>> upsertBatch(List<Map<String, dynamic>> recipes) async {
    final uri = Uri.parse('$_baseUrl/recipes/upsert-batch');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _tokenProvider?.call();
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    final resp = await _client.post(uri, headers: headers, body: jsonEncode({'recipes': recipes}));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Failed to upsert recipes (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final List<dynamic> arr = (decoded['recipes'] as List?) ?? const [];
    return arr.map((e) => _fromBackend(e as Map<String, dynamic>)).toList(growable: false);
  }

  Recipe _fromBackend(Map<String, dynamic> json) {
    final List<dynamic> tags = (json['tags'] as List?) ?? const [];
    final List<dynamic> steps = (json['steps'] as List?) ?? const [];
    final List<dynamic> ings = (json['ingredientsJson'] as List?) ?? const [];
    const fallbackImage = 'https://picsum.photos/500/300';
    String _image(String? raw) {
      final img = raw?.trim();
      if (img == null || img.isEmpty) return fallbackImage;
      if (img == 'https://example.com/soupe_oignon.jpg') {
        return fallbackImage;
      }
      return img;
    }
    return Recipe(
      id: (json['id'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      image: _image(json['imageUrl'] as String?),
      readyInMin: json['readyInMin'] as int?,
      servings: json['servings'] as int?,
      tags: tags.map((e) => e.toString()).toList(growable: false),
      ingredients: ings
          .whereType<Map<String, dynamic>>()
          .map((e) => Ingredient.fromJson(e))
          .toList(growable: false),
      steps: steps.map((e) => e.toString()).toList(growable: false),
      nutrition: NutritionInfo.fromJson(json['nutrition'] as Map<String, dynamic>?),
    );
  }
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
