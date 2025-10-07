import 'dart:convert';

import '../../recipes/models/ingredient.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/models/shopping_item.dart';
import '../../recipes/services/recipe_repository.dart';
import '../../recipes/services/shopping_list_repository.dart';
import '../../recipes/services/recipe_api.dart';
import '../../recipes/services/shopping_api.dart';
import '../../recipes/utils.dart';
import '../../weight/services/weight_api.dart';
import '../../weight/services/weight_repository.dart';

class ChatHooks {
  ChatHooks._();

  static Map<String, dynamic>? _extractJsonObject(String reply) {
    // Try to extract a JSON object or array from a free-form reply.
    final text = reply.trim();
    // Heuristic 1: after optional ACTIONS: label
    final idxActions = text.toUpperCase().indexOf('ACTIONS');
    final source = idxActions >= 0 ? text.substring(idxActions) : text;

    // Try object first
    final startObj = source.indexOf('{');
    final endObj = source.lastIndexOf('}');
    if (startObj != -1 && endObj != -1 && endObj > startObj) {
      final candidate = source.substring(startObj, endObj + 1);
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          return decoded.first as Map<String, dynamic>;
        }
      } catch (_) {
        // ignore and fallback
      }
    }
    // Try array
    final startArr = source.indexOf('[');
    final endArr = source.lastIndexOf(']');
    if (startArr != -1 && endArr != -1 && endArr > startArr) {
      try {
        final decoded = jsonDecode(source.substring(startArr, endArr + 1));
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          return decoded.first as Map<String, dynamic>;
        }
      } catch (_) {
        // ignore
      }
    }
    return null;
  }

  // Expose parsed structured payload if present
  static Map<String, dynamic>? tryParseStructuredPayload(String reply) {
    final obj = _extractJsonObject(reply);
    if (obj == null) return null;
    final type = (obj['type'] as String? ?? '').trim();
    if (type.isEmpty) return null;
    return obj;
  }

  static Future<String?> processStructuredPayloadFromReply({
    required String reply,
    required String userId,
    String? Function()? tokenProvider,
  }) async {
    final Map<String, dynamic>? obj = _extractJsonObject(reply);
    if (obj == null) return null;
    final type = (obj['type'] as String? ?? '').trim();
    if (type == 'recipe_batch') {
      final List<dynamic> rawRecipes = (obj['recipes'] as List?) ?? const [];
      final recipes = rawRecipes
          .whereType<Map<String, dynamic>>()
          .map((e) => Recipe.fromJson(e))
          .where((r) => r.id.isNotEmpty && r.title.isNotEmpty)
          .toList(growable: false);
      RecipeRepository.instance.upsertAll(recipes);
      // Persist recipes to backend (fire-and-forget)
      try {
        final api = RecipeApi(tokenProvider: tokenProvider);
        final payload = rawRecipes.whereType<Map<String, dynamic>>().toList(growable: false);
        api.upsertBatch(payload).then((serverRecipes) {
          RecipeRepository.instance.upsertAll(serverRecipes);
        }).catchError((_) {});
      } catch (_) {}

      // Also add all ingredients to default shopping list with dedup/merge
      final items = <ShoppingItem>[];
      for (final r in recipes) {
        for (final ing in r.ingredients) {
          items.add(
            ShoppingItem.fromIngredient(
              name: ing.name,
              qty: ing.qty,
              unit: ing.unit,
              category: ing.category,
              note: 'recette ${r.title}',
            ),
          );
        }
      }
      if (items.isNotEmpty) {
        ShoppingListRepository.instance.addOrMergeItems('default', items);
        // Persist to backend
        try {
          final sApi = ShoppingApi(tokenProvider: tokenProvider);
          final ops = items
              .map((e) => ShoppingOp(
                    name: e.displayName,
                    qty: e.qty,
                    unit: e.unit,
                    category: e.category,
                    note: e.note,
                    op: 'add',
                  ))
              .toList(growable: false);
          sApi.applyOps('default', ops).then((serverItems) {
            ShoppingListRepository.instance.replaceAll('default', serverItems);
          }).catchError((_) {});
        } catch (_) {}
      }
      return null;
    }

    if (type == 'shopping_list_update') {
      final listId = (obj['listId'] as String? ?? 'default').trim();
      final List<dynamic> rawOps = (obj['items'] as List?) ?? const [];
      final ops = rawOps
          .whereType<Map<String, dynamic>>()
          .map((e) => ShoppingOp.fromJson(e))
          .toList(growable: false);
      if (ops.isNotEmpty) {
        ShoppingListRepository.instance.applyOps(listId, ops);
        try {
          final sApi = ShoppingApi(tokenProvider: tokenProvider);
          sApi.applyOps(listId, ops).then((serverItems) {
            ShoppingListRepository.instance.replaceAll(listId, serverItems);
          }).catchError((_) {});
        } catch (_) {}
      }
      return null;
    }

    if (type == 'weight_log') {
      final weightValue = (obj['weightKg'] as num?)?.toDouble();
      final dateRaw = obj['date'];
      final note = (obj['note'] as String?)?.trim();
      if (weightValue == null || dateRaw == null) {
        return null;
      }

      DateTime? parsedDate;
      if (dateRaw is String && dateRaw.isNotEmpty) {
        try {
          parsedDate = DateTime.parse(dateRaw);
        } catch (_) {}
      } else if (dateRaw is num) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(dateRaw.toInt(), isUtc: true);
      }
      parsedDate ??= DateTime.now();

      if (tokenProvider == null) {
        return null;
      }

      try {
        final api = WeightApi(tokenProvider: tokenProvider);
        final entry = await api.createEntry(
          weightKg: weightValue,
          date: parsedDate,
          note: note,
        );
        WeightRepository.instance.applyServerEntry(entry);

        final localDate = entry.date.toLocal();
        final formattedDate =
            '${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}/${localDate.year}';
        final weightText = entry.weightKg.toStringAsFixed(1).replaceAll('.', ',');
        return 'Poids enregistré : $weightText kg (le $formattedDate).';
      } catch (_) {
        return null;
      }
    }

    return null;
  }
}
