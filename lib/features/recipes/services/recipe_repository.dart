import 'dart:async';

import '../models/recipe.dart';

class RecipeRepository {
  RecipeRepository._();
  static final RecipeRepository instance = RecipeRepository._();

  final Map<String, Recipe> _byId = <String, Recipe>{};
  StreamController<List<Recipe>>? _controller;

  StreamController<List<Recipe>> _ensureController() {
    return _controller ??= StreamController<List<Recipe>>.broadcast(
      onListen: _emit,
    );
  }

  Stream<List<Recipe>> watchAll() => _ensureController().stream;

  List<Recipe> getAll() => _byId.values.toList(growable: false);

  Recipe? getById(String id) => _byId[id];

  void replaceAll(List<Recipe> items) {
    _byId
      ..clear()
      ..addEntries(items.where((r) => r.id.isNotEmpty).map((r) => MapEntry(r.id, r)));
    _emit();
  }

  void upsertAll(List<Recipe> items) {
    bool changed = false;
    for (final r in items) {
      if (r.id.isEmpty || r.title.isEmpty) continue;
      final prev = _byId[r.id];
      if (prev != r) {
        _byId[r.id] = r;
        changed = true;
      }
    }
    if (changed) {
      _emit();
    }
  }

  void _emit() {
    final list = _byId.values.toList(growable: false);
    final ctrl = _ensureController();
    if (!ctrl.isClosed) ctrl.add(list);
  }
}
