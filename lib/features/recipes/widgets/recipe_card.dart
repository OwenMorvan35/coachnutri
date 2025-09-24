import 'package:flutter/material.dart';

import '../models/recipe.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.recipe, this.onTap});

  final Recipe recipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outlineVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Smaller visual: 16:9 image for a more compact card
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: recipe.image != null && recipe.image!.isNotEmpty
                        ? Image.network(recipe.image!, fit: BoxFit.cover)
                        : Container(
                            color: theme.colorScheme.surfaceVariant,
                            alignment: Alignment.center,
                            child: Icon(Icons.image_rounded, color: theme.colorScheme.outline),
                          ),
                  ),
                  // Overlay pill for quick info (time / servings)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _InfoPill(
                      readyInMin: recipe.readyInMin,
                      servings: recipe.servings,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (recipe.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: -8,
                      children: recipe.tags.take(2).map((t) => _TagChip(text: t)).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({this.readyInMin, this.servings});
  final int? readyInMin;
  final int? servings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <Widget>[];
    if (readyInMin != null) {
      items.add(Row(children: [
        const Icon(Icons.schedule_rounded, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text('${readyInMin!}m', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]));
    }
    if (servings != null) {
      if (items.isNotEmpty) items.add(const SizedBox(width: 8));
      items.add(Row(children: [
        const Icon(Icons.person_rounded, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text('${servings!}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: items),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
