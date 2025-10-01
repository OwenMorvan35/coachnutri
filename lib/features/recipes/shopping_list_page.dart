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
    final toBuy = _collectItems(inCart: false);
    final inCartItems = _collectItems(inCart: true);
    return Scaffold(
      appBar: AppBar(title: const Text('Liste de courses')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                Text('À acheter', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _buildGrid(context, toBuy, inCart: false),
                const SizedBox(height: 28),
                Text('Dans le panier', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _buildGrid(context, inCartItems, inCart: true),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: _inputDecoration(theme, hint: 'Ajouter un ingrédient…'),
                    onSubmitted: (_) => _addQuick(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 52,
                  width: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    onPressed: _addQuick,
                    child: const Icon(Icons.add_rounded, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<ShoppingItem> items,
      {required bool inCart}) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4), width: 1.3),
        ),
        child: Text(
          inCart ? 'Aucun article dans le panier.' : 'Aucun article à acheter.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isPhone = shortestSide < 600;
    int crossAxisCount;
    if (isPhone) {
      crossAxisCount = (width / 110).floor().clamp(3, 4);
    } else {
      crossAxisCount = (width / 160).floor().clamp(4, 6);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ShoppingTile(
          item: item,
          isInCart: inCart,
          onToggle: () => _toggleItem(item.nameKey),
          onRemove: () => _removeItem(item.nameKey),
        );
      },
    );
  }

  List<ShoppingItem> _collectItems({required bool inCart}) {
    final list = <ShoppingItem>[];
    _groups.forEach((_, items) {
      list.addAll(items.where((item) => item.isChecked == inCart));
    });
    list.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return list;
  }

  InputDecoration _inputDecoration(ThemeData theme, {required String hint}) {
    final baseBorder = const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Color(0xFF424242), width: 1.4),
    );
    return InputDecoration(
      hintText: hint,
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
}

class _ShoppingTile extends StatelessWidget {
  const _ShoppingTile({
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
    final background = isInCart ? const Color(0xFF55C0A6) : const Color(0xFFFF6F6F);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: () {
                    onRemove();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isInCart ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
                        size: 22,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.displayName,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          decoration: isInCart ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
