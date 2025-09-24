import 'package:flutter/material.dart';

import '../../core/session.dart';
import 'models/recipe.dart';
import 'models/shopping_item.dart';
import 'services/shopping_api.dart';
import 'services/shopping_list_repository.dart';

class RecipeDetailPage extends StatelessWidget {
  const RecipeDetailPage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(recipe.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: recipe.image != null && recipe.image!.isNotEmpty
                  ? Image.network(recipe.image!, fit: BoxFit.cover)
                  : Container(
                      color: theme.colorScheme.surfaceVariant,
                      alignment: Alignment.center,
                      child:
                          Icon(Icons.image_rounded, color: theme.colorScheme.outline),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: -6,
            children: [
              if (recipe.readyInMin != null)
                Chip(label: Text('${recipe.readyInMin} min')),
              if (recipe.servings != null)
                Chip(label: Text('${recipe.servings} pers.')),
              for (final t in recipe.tags)
                Chip(label: Text(t)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Ingrédients', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final ing in recipe.ingredients)
            Text('• ${ing.name}${ing.qty != null ? ' – ${ing.qty}${ing.unit ?? ''}' : ''}'),
          const SizedBox(height: 16),
          Text('Étapes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (int i = 0; i < recipe.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${i + 1}. ${recipe.steps[i]}'),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _addToList(context),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Ajouter ingrédients à la liste'),
          ),
        ],
      ),
    );
  }

  void _addToList(BuildContext context) {
    final items = recipe.ingredients
        .map((ing) => ShoppingItem.fromIngredient(
              name: ing.name,
              qty: ing.qty,
              unit: ing.unit,
              category: ing.category,
              note: 'recette ${recipe.title}',
            ))
        .toList(growable: false);
    if (items.isEmpty) return;
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
    final tokenProvider = () => SessionScope.of(context, listen: false).session?.token;
    final api = ShoppingApi(tokenProvider: tokenProvider);
    api.applyOps('default', ops).then((serverItems) {
      ShoppingListRepository.instance.replaceAll(
        'default',
        serverItems,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingrédients ajoutés à la liste')),
        );
      }
    }).catchError((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Échec de l'ajout à la liste")),
        );
      }
    });
  }
}
