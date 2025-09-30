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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'Aucune recette pour le moment',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Responsive breakpoints for columns
        final int columns = width < 420
            ? 2
            : width < 720
                ? 3
                : width < 1024
                    ? 4
                    : 5;
        final double ratio = columns <= 2
            ? 0.80
            : columns == 3
                ? 0.72
                : columns == 4
                    ? 0.66
                    : 0.68; // 5+

        return GridView.builder(
          primary: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: ratio,
          ),
          itemCount: _recipes.length,
          itemBuilder: (context, index) {
            final r = _recipes[index];
            return RecipeCard(recipe: r, onTap: () => widget.onOpenDetails(r));
          },
        );
      },
    );
  }
}
