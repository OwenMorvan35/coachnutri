import 'package:flutter_test/flutter_test.dart';

import 'package:coachnutri/features/recipes/models/shopping_item.dart';
import 'package:coachnutri/features/recipes/services/shopping_list_repository.dart';

void main() {
  test('merge items with same key and unit sums qty', () {
    final repo = ShoppingListRepository.instance;
    repo.addOrMergeItems('default', [
      ShoppingItem.fromIngredient(name: 'Tomates', qty: 2, unit: 'pcs'),
      ShoppingItem.fromIngredient(name: 'tomate', qty: 3, unit: 'pcs'),
    ]);

    final stream = repo.watchGrouped('default');
    expectLater(stream, emitsThrough(predicate((dynamic data) {
      final map = data as Map<String, List<ShoppingItem>>;
      final all = map.values.expand((e) => e).toList();
      final tomatoes = all.firstWhere((e) => e.nameKey == 'tomates' || e.nameKey == 'tomate', orElse: () => all.first);
      return tomatoes.qty == 5 && tomatoes.unit == 'pcs';
    })));
  });

  test('toggle moves item to bottom of its group', () async {
    final repo = ShoppingListRepository.instance;
    repo.addOrMergeItems('default', [
      ShoppingItem.fromIngredient(name: 'Lait'),
      ShoppingItem.fromIngredient(name: 'Beurre'),
    ]);
    final groups1 = await repo.watchGrouped('default').first;
    final dairy = groups1['cremerie'] ?? groups1.values.first;
    final firstNameKey = dairy.first.nameKey;
    repo.toggleItem('default', firstNameKey);
    final groups2 = await repo.watchGrouped('default').first;
    final dairy2 = groups2['cremerie'] ?? groups2.values.first;
    expect(dairy2.last.nameKey, firstNameKey);
    expect(dairy2.last.isChecked, true);
  });
}
