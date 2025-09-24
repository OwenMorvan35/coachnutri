import 'dart:async';

import '../models/shopping_item.dart';
import '../utils.dart';

class ShoppingListRepository {
  ShoppingListRepository._();
  static final ShoppingListRepository instance = ShoppingListRepository._();

  // listId -> nameKey -> item
  final Map<String, Map<String, ShoppingItem>> _lists = <String, Map<String, ShoppingItem>>{};
  final Map<String, StreamController<Map<String, List<ShoppingItem>>>> _controllers =
      <String, StreamController<Map<String, List<ShoppingItem>>>>{};

  Stream<Map<String, List<ShoppingItem>>> watchGrouped(String listId) {
    final id = listId.isEmpty ? 'default' : listId;
    final controller = _controllers[id] ??= StreamController<Map<String, List<ShoppingItem>>>.broadcast(
      onListen: () => _emit(id),
    );
    return controller.stream;
  }

  void replaceAll(String listId, List<ShoppingItem> items) {
    final id = listId.isEmpty ? 'default' : listId;
    final map = <String, ShoppingItem>{};
    for (final it in items) {
      map[it.nameKey] = it;
    }
    _lists[id] = map;
    _emit(id);
  }

  void addOrMergeItems(String listId, List<ShoppingItem> items) {
    final id = listId.isEmpty ? 'default' : listId;
    final map = _lists[id] ??= <String, ShoppingItem>{};
    bool changed = false;
    for (final it in items) {
      final key = toKey(it.displayName);
      if (key.isEmpty) continue;
      final existing = map[key];
      if (existing == null) {
        map[key] = ShoppingItem(
          displayName: it.displayName,
          nameKey: key,
          qty: it.qty,
          unit: it.unit,
          category: mapCategory(it.category),
          note: it.note,
          isChecked: false,
        );
        changed = true;
      } else {
        // Merge rule: same nameKey and unit -> sum qty; else keep latest qty and concat note
        if ((existing.unit ?? '') == (it.unit ?? '')) {
          final a = existing.qty ?? 0;
          final b = it.qty ?? 0;
          existing.qty = a + b;
        } else {
          existing.qty = it.qty ?? existing.qty;
          existing.unit = it.unit ?? existing.unit;
        }
        if (it.note != null && it.note!.isNotEmpty) {
          existing.note = existing.note == null || existing.note!.isEmpty
              ? it.note
              : '${existing.note} | ${it.note}';
        }
        existing.category = mapCategory(it.category ?? existing.category);
        existing.updatedAt = DateTime.now();
        changed = true;
      }
    }
    if (changed) _emit(id);
  }

  void toggleItem(String listId, String nameKey) {
    final id = listId.isEmpty ? 'default' : listId;
    final map = _lists[id];
    if (map == null) return;
    final item = map[nameKey];
    if (item == null) return;
    item.isChecked = !item.isChecked;
    item.updatedAt = DateTime.now();
    _emit(id);
  }

  void removeItem(String listId, String nameKey) {
    final id = listId.isEmpty ? 'default' : listId;
    final map = _lists[id];
    if (map == null) return;
    map.remove(nameKey);
    _emit(id);
  }

  void applyOps(String listId, List<ShoppingOp> ops) {
    if (ops.isEmpty) return;
    final id = listId.isEmpty ? 'default' : listId;
    for (final op in ops) {
      final key = toKey(op.name);
      if (key.isEmpty) continue;
      switch (op.op) {
        case 'add':
          addOrMergeItems(
            id,
            [
              ShoppingItem.fromIngredient(
                name: op.name,
                qty: op.qty,
                unit: op.unit,
                category: op.category,
                note: op.note,
              ),
            ],
          );
          break;
        case 'remove':
          removeItem(id, key);
          break;
        case 'toggle':
          toggleItem(id, key);
          break;
        default:
          // ignore unknown op
          break;
      }
    }
  }

  Map<String, List<ShoppingItem>> _groupByCategory(String listId) {
    final id = listId.isEmpty ? 'default' : listId;
    final map = _lists[id] ?? const <String, ShoppingItem>{};
    final groups = <String, List<ShoppingItem>>{};
    for (final item in map.values) {
      final cat = mapCategory(item.category);
      (groups[cat] ??= <ShoppingItem>[]).add(item);
    }
    // Sort each group: unchecked first, then by updatedAt asc, then name
    for (final entry in groups.entries) {
      entry.value.sort((a, b) {
        if (a.isChecked != b.isChecked) {
          return a.isChecked ? 1 : -1; // unchecked first
        }
        final ts = a.updatedAt.compareTo(b.updatedAt);
        if (ts != 0) return ts;
        return a.displayName.compareTo(b.displayName);
      });
    }
    return groups;
  }

  void _emit(String listId) {
    final controller = _controllers[listId] ??= StreamController<Map<String, List<ShoppingItem>>>.broadcast();
    controller.add(_groupByCategory(listId));
  }
}
