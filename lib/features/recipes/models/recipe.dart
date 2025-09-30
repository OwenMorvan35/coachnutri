import 'ingredient.dart';

class NutritionInfo {
  const NutritionInfo({this.kcal, this.proteinG, this.carbG, this.fatG});

  final num? kcal;
  final num? proteinG;
  final num? carbG;
  final num? fatG;

  factory NutritionInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NutritionInfo();
    num? _num(Object? v) => v is num ? v : num.tryParse(v?.toString() ?? '');
    return NutritionInfo(
      kcal: _num(json['kcal']),
      proteinG: _num(json['protein_g'] ?? json['proteinG']),
      carbG: _num(json['carb_g'] ?? json['carbG']),
      fatG: _num(json['fat_g'] ?? json['fatG']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (kcal != null) 'kcal': kcal,
        if (proteinG != null) 'protein_g': proteinG,
        if (carbG != null) 'carb_g': carbG,
        if (fatG != null) 'fat_g': fatG,
      };
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    this.image,
    this.readyInMin,
    this.servings,
    this.tags = const <String>[],
    this.ingredients = const <Ingredient>[],
    this.steps = const <String>[],
    this.nutrition = const NutritionInfo(),
  });

  final String id;
  final String title;
  final String? image;
  final int? readyInMin;
  final int? servings;
  final List<String> tags;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final NutritionInfo nutrition;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final List<dynamic> ingredientsRaw = (json['ingredients'] as List?) ?? const [];
    final List<dynamic> stepsRaw = (json['steps'] as List?) ?? const [];
    final List<dynamic> tagsRaw = (json['tags'] as List?) ?? const [];
    const fallbackImage = 'https://picsum.photos/500/300';
    String _image(String? raw) {
      final img = raw?.trim();
      if (img == null || img.isEmpty) return fallbackImage;
      if (img == 'https://example.com/soupe_oignon.jpg') {
        return fallbackImage;
      }
      return img;
    }
    final imageRaw = (json['image'] ?? json['imageUrl']) as String?;
    return Recipe(
      id: (json['id'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      image: _image(imageRaw),
      readyInMin: _tryParseInt(json['readyInMin']),
      servings: _tryParseInt(json['servings']),
      tags: tagsRaw.map((e) => e.toString()).toList(growable: false),
      ingredients: ingredientsRaw
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      steps: stepsRaw.map((e) => e.toString()).toList(growable: false),
      nutrition: NutritionInfo.fromJson(
        json['nutrition'] as Map<String, dynamic>?,
      ),
    );
  }
}

int? _tryParseInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
