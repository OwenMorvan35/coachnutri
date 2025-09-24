import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session.dart';
import 'models/shopping_item.dart';
import 'services/shopping_api.dart';
import 'services/shopping_list_repository.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key, this.listId = 'default'});

  final String listId;

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  late final StreamSubscription<Map<String, List<ShoppingItem>>> _sub;
  Map<String, List<ShoppingItem>> _groups = const <String, List<ShoppingItem>>{};
  final TextEditingController _controller = TextEditingController();
  late final ShoppingApi _api;

  @override
  void initState() {
    super.initState();
    final tokenProvider = () => SessionScope.of(context, listen: false).session?.token;
    _api = ShoppingApi(tokenProvider: tokenProvider);
    _sub = ShoppingListRepository.instance
        .watchGrouped(widget.listId)
        .listen((data) {
      if (!mounted) return;
      setState(() => _groups = data);
    });
    _load();
  }

  @override
  void dispose() {
    _sub.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _api.fetchAll(widget.listId);
      ShoppingListRepository.instance.replaceAll(widget.listId, items);
    } catch (_) {
      // ignore transient errors; UI remains empty
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Liste de courses')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _quickAddField(theme),
          const SizedBox(height: 16),
          // Super section: À acheter (non cochés)
          Text('À acheter', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._buildCategorySections(theme, inCart: false),
          const SizedBox(height: 20),
          // Super section: Dans le panier (cochés)
          Text('Dans le panier', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._buildCategorySections(theme, inCart: true),
        ],
      ),
    );
  }

  List<Widget> _buildCategorySections(ThemeData theme, {required bool inCart}) {
    final widgets = <Widget>[];
    _groups.forEach((categoryKey, items) {
      final filtered = items.where((e) => e.isChecked == inCart).toList();
      if (filtered.isEmpty) return;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(_labelFor(categoryKey), style: theme.textTheme.titleSmall),
      ));
      widgets.add(
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: filtered
              .map((e) => _ItemCard(
                    item: e,
                    isInCart: inCart,
                    onToggle: () => _toggleItem(e.nameKey),
                    onRemove: () => _removeItem(e.nameKey),
                  ))
              .toList(),
        ),
      );
    });
    if (widgets.isEmpty) {
      widgets.add(
        Text(
          inCart ? 'Aucun article dans le panier.' : 'Aucun article à acheter.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return widgets;
  }

  Widget _quickAddField(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Ajouter un article…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _addQuick(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _addQuick,
          child: const Text('Ajouter'),
        ),
      ],
    );
  }

  void _addQuick() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    final op = ShoppingOp(name: raw, op: 'add');
    _api.applyOps(widget.listId, [op]).then((serverItems) {
      ShoppingListRepository.instance.replaceAll(widget.listId, serverItems);
      _controller.clear();
    }).catchError((_) {
      // ignore
    });
  }

  void _toggleItem(String nameKey) {
    // We don't know the display name here; using nameKey is fine for toggle endpoint spec
    final op = ShoppingOp(name: nameKey, op: 'toggle');
    _api.applyOps(widget.listId, [op]).then((serverItems) {
      ShoppingListRepository.instance.replaceAll(widget.listId, serverItems);
    }).catchError((_) {
      // ignore
    });
  }

  void _removeItem(String nameKey) {
    final op = ShoppingOp(name: nameKey, op: 'remove');
    _api.applyOps(widget.listId, [op]).then((serverItems) {
      ShoppingListRepository.instance.replaceAll(widget.listId, serverItems);
    }).catchError((_) {});
  }

  String _labelFor(String key) {
    switch (key) {
      case 'boucherie':
        return 'Boucherie';
      case 'fruits_legumes':
        return 'Fruits & Légumes';
      case 'cremerie':
        return 'Crèmerie';
      case 'boulangerie':
        return 'Boulangerie';
      case 'surgele':
        return 'Surgelés';
      case 'boissons':
        return 'Boissons';
      case 'epicerie':
        return 'Épicerie';
      default:
        return 'Autres';
    }
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.isInCart,
    required this.onToggle,
    required this.onRemove,
  });

  final ShoppingItem item;
  final bool isInCart;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isInCart ? theme.colorScheme.error : theme.colorScheme.primary;
    final bg = color.withOpacity(0.08);
    final border = color.withOpacity(0.22);
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        constraints: const BoxConstraints(minWidth: 120),
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(isInCart ? Icons.check_circle_rounded : Icons.add_circle_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      decoration: isInCart ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.qty != null)
                    Text(
                      '${item.qty}${item.unit ?? ''}${item.note != null && item.note!.isNotEmpty ? ' · ${item.note}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(color: color.withOpacity(0.9)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(Icons.delete_outline_rounded, size: 18, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
