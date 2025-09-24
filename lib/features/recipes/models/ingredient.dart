class Ingredient {
  const Ingredient({
    required this.name,
    this.qty,
    this.unit,
    this.category,
  });

  final String name;
  final num? qty;
  final String? unit;
  final String? category;

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: (json['name'] as String? ?? '').trim(),
      qty: json['qty'] is num ? json['qty'] as num : _tryParseNum(json['qty']),
      unit: (json['unit'] as String?)?.trim(),
      category: (json['category'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (qty != null) 'qty': qty,
        if (unit != null) 'unit': unit,
        if (category != null) 'category': category,
      };
}

num? _tryParseNum(Object? value) {
  if (value == null) return null;
  if (value is num) return value;
  final s = value.toString();
  return num.tryParse(s);
}

