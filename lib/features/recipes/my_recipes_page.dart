import 'package:flutter/material.dart';

import 'services/recipe_api.dart';
import '../../core/session.dart';
import 'models/recipe.dart';
import 'recipe_detail_page.dart';
import 'services/recipe_repository.dart';
import 'widgets/recipe_grid.dart';

class MyRecipesPage extends StatefulWidget {
  const MyRecipesPage({super.key});

  @override
  State<MyRecipesPage> createState() => _MyRecipesPageState();
}

class _MyRecipesPageState extends State<MyRecipesPage> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tokenProvider = () => SessionScope.of(context, listen: false).session?.token;
      final api = RecipeApi(tokenProvider: tokenProvider);
      final recipes = await api.fetchAll();
      RecipeRepository.instance.replaceAll(recipes);
    } catch (e) {
      _error = 'Impossible de charger les recettes';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes recettes')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : RecipeGrid(onOpenDetails: (Recipe r) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: r)),
                    );
                  }),
      ),
    );
  }
}
