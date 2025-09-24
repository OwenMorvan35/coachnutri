import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/shopping_item.dart';
import '../utils.dart';

class ShoppingApi {
  ShoppingApi({String? baseUrl, String? Function()? tokenProvider})
      : _baseUrl = baseUrl ?? _resolveBaseUrl(),
        _tokenProvider = tokenProvider,
        _client = http.Client();

  final String _baseUrl;
  final String? Function()? _tokenProvider;
  final http.Client _client;

  Future<List<ShoppingItem>> fetchAll(String listId) async {
    final id = listId.isEmpty ? 'default' : listId;
    final uri = Uri.parse('$_baseUrl/shopping-lists/$id/items');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _tokenProvider?.call();
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    final resp = await _client.get(uri, headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Failed to fetch shopping items (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final List<dynamic> arr = (decoded['items'] as List?) ?? const [];
    return arr.map((e) => _fromBackend(e as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<ShoppingItem>> applyOps(String listId, List<ShoppingOp> ops) async {
    final id = listId.isEmpty ? 'default' : listId;
    final uri = Uri.parse('$_baseUrl/shopping-lists/$id/items/apply');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _tokenProvider?.call();
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    final body = {
      'items': ops
          .map((o) => {
                'name': o.name,
                if (o.qty != null) 'qty': o.qty,
                if (o.unit != null) 'unit': o.unit,
                if (o.category != null) 'category': o.category,
                if (o.note != null) 'note': o.note,
                'op': o.op,
              })
          .toList(growable: false)
    };
    final resp = await _client.post(uri, headers: headers, body: jsonEncode(body));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Failed to apply shopping ops (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final List<dynamic> arr = (decoded['items'] as List?) ?? const [];
    return arr.map((e) => _fromBackend(e as Map<String, dynamic>)).toList(growable: false);
  }

  ShoppingItem _fromBackend(Map<String, dynamic> json) {
    final name = (json['displayName'] as String? ?? '').trim();
    return ShoppingItem(
      displayName: name,
      nameKey: json['nameKey'] as String? ?? toKey(name),
      qty: json['qty'] as num?,
      unit: json['unit'] as String?,
      category: json['category'] as String? ?? 'autres',
      note: json['note'] as String?,
      isChecked: (json['isChecked'] as bool?) ?? false,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
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
