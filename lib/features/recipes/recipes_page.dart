import 'package:flutter/material.dart';

import '../../core/logger.dart';

/// Placeholder page for recipes and shopping list sections.
class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  @override
  void initState() {
    super.initState();
    Logger.i('RECIPES_PAGE', 'RecipesPage initState');
  }

  @override
  void dispose() {
    Logger.i('RECIPES_PAGE', 'RecipesPage dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildHeroCard(theme),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildQuickActions(theme),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildRecipeIdeas(theme),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildShoppingList(theme),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeroCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF3A86FF), Color(0xFF4CC9F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F3A86FF),
            offset: Offset(0, 18),
            blurRadius: 36,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recettes sur-mesure',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Des idées équilibrées adaptées à ton objectif et à tes préférences.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            color: const Color(0xFFFFF1C6),
            icon: Icons.flash_on_rounded,
            title: 'Rapide',
            subtitle: 'Prêt en 15 min',
            onTap: () => Logger.i('RECIPES_TAP', 'Quick recipes tapped'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            color: const Color(0xFFE7E4FF),
            icon: Icons.calendar_month_rounded,
            title: 'Batch cooking',
            subtitle: 'Prépare ta semaine',
            onTap: () => Logger.i('RECIPES_TAP', 'Batch cooking quick action tapped'),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeIdeas(ThemeData theme) {
    final cards = [
      _RecipeIdeaCard(
        title: 'Bowl protéiné',
        description: 'Quinoa, pois chiches, légumes verts, sauce tahini.',
        icon: Icons.bolt_rounded,
        gradient: const [Color(0xFF8338EC), Color(0xFF3A86FF)],
        onTap: () => Logger.i('RECIPES_TAP', 'Bowl protéiné tapped'),
      ),
      _RecipeIdeaCard(
        title: 'Salade énergie',
        description: 'Avocat, saumon, agrumes, graines de courge.',
        icon: Icons.energy_savings_leaf_rounded,
        gradient: const [Color(0xFF4CC9F0), Color(0xFF4895EF)],
        onTap: () => Logger.i('RECIPES_TAP', 'Salade énergie tapped'),
      ),
    ];

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) => cards[index],
        separatorBuilder: (context, _) => const SizedBox(width: 12),
        itemCount: cards.length,
      ),
    );
  }

  Widget _buildShoppingList(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Liste de courses intelligente', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _ShoppingListTile(
              icon: Icons.apple_outlined,
              title: 'Fruits & légumes',
              subtitle: 'Pommes, épinards, courgettes, citron.',
              onTap: () => Logger.i('RECIPES_TAP', 'Fruits & légumes tapped'),
            ),
            const Divider(),
            _ShoppingListTile(
              icon: Icons.set_meal_outlined,
              title: 'Protéines',
              subtitle: 'Tofu, poulet, pois chiches, yaourts grecs.',
              onTap: () => Logger.i('RECIPES_TAP', 'Protéines tapped'),
            ),
            const Divider(),
            _ShoppingListTile(
              icon: Icons.grass_rounded,
              title: 'Épicerie saine',
              subtitle: 'Flocons d’avoine, graines, huile d’olive, épices.',
              onTap: () => Logger.i('RECIPES_TAP', 'Épicerie saine tapped'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeIdeaCard extends StatelessWidget {
  const _RecipeIdeaCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F1F2937),
              offset: Offset(0, 16),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingListTile extends StatelessWidget {
  const _ShoppingListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: onTap,
    );
  }
}
