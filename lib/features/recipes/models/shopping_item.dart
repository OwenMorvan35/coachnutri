import '../utils.dart';

class ShoppingItem {
  ShoppingItem({
    required this.displayName,
    required this.nameKey,
    this.qty,
    this.unit,
    this.category = 'autres',
    this.note,
    this.isChecked = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String displayName;
  final String nameKey;
  num? qty;
  String? unit;
  String category;
  String? note;
  bool isChecked;
  DateTime updatedAt;

  factory ShoppingItem.fromIngredient({
    required String name,
    num? qty,
    String? unit,
    String? category,
    String? note,
  }) {
    final normalizedCategory = mapCategory(category);
    return ShoppingItem(
      displayName: name,
      nameKey: toKey(name),
      qty: qty,
      unit: unit?.trim(),
      category: normalizedCategory,
      note: note?.trim(),
    );
  }
}

class ShoppingOp {
  const ShoppingOp({
    required this.name,
    this.qty,
    this.unit,
    this.category,
    this.note,
    required this.op,
  });

  final String name;
  final num? qty;
  final String? unit;
  final String? category;
  final String? note;
  final String op; // add | remove | toggle

  factory ShoppingOp.fromJson(Map<String, dynamic> json) {
    return ShoppingOp(
      name: (json['name'] as String? ?? '').trim(),
      qty: json['qty'] is num ? json['qty'] as num : _tryParseNum(json['qty']),
      unit: (json['unit'] as String?)?.trim(),
      category: (json['category'] as String?)?.trim(),
      note: (json['note'] as String?)?.trim(),
      op: (json['op'] as String? ?? '').trim(),
    );
  }
}

num? _tryParseNum(Object? value) {
  if (value == null) return null;
  if (value is num) return value;
  final s = value.toString();
  return num.tryParse(s);
}

