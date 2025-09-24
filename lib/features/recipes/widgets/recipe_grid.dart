import 'dart:async';

import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_repository.dart';
import 'recipe_card.dart';

class RecipeGrid extends StatefulWidget {
  const RecipeGrid({super.key, required this.onOpenDetails});

  final void Function(Recipe recipe) onOpenDetails;

  @override
  State<RecipeGrid> createState() => _RecipeGridState();
}

class _RecipeGridState extends State<RecipeGrid> {
  late final StreamSubscription<List<Recipe>> _sub;
  List<Recipe> _recipes = const <Recipe>[];

  @override
  void initState() {
    super.initState();
    _sub = RecipeRepository.instance.watchAll().listen((items) {
      if (!mounted) return;
      setState(() => _recipes = items);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recipes.isEmpty) {
      return const SizedBox.shrink();
    }
    return GridView.builder(
      primary: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.0,
      ),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final r = _recipes[index];
        return RecipeCard(recipe: r, onTap: () => widget.onOpenDetails(r));
      },
    );
  }
}
