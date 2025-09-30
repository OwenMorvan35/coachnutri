import 'package:flutter/material.dart';

import '../../core/logger.dart';
import '../../core/session.dart';
import '../chat/chat_page.dart';
import '../recipes/recipes_page.dart';
import '../weight/weight_page.dart';
import '../profile/identity/identity_page.dart';
import '../../ui/widgets/blurred_nav_bar.dart';

/// Root scaffold handling global navigation and layout.
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  late final List<Widget> _pages;
  int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
    Logger.i('SHELL_PAGE', 'ShellPage initState');
    _pages = const [RecipesPage(), ChatPage(), WeightPage()];
  }

  @override
  void dispose() {
    Logger.i('SHELL_PAGE', 'ShellPage dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionController = SessionScope.of(context);
    final authUser = sessionController.session?.user;
    final avatarUrl = authUser?.avatarUrl;
    final initials = (authUser?.displayName ?? authUser?.name ?? authUser?.email ?? 'U')
        .trim()
        .isNotEmpty
        ? (authUser?.displayName ?? authUser?.name ?? authUser?.email ?? 'U')[0].toUpperCase()
        : 'U';
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.restaurant_menu_outlined),
        selectedIcon: Icon(Icons.restaurant_menu_rounded),
        label: 'Recettes',
      ),
      const NavigationDestination(
        icon: Icon(Icons.chat_bubble_outline_rounded),
        selectedIcon: Icon(Icons.chat_bubble_rounded),
        label: 'Coach',
      ),
      const NavigationDestination(
        icon: Icon(Icons.monitor_weight_outlined),
        selectedIcon: Icon(Icons.monitor_weight_rounded),
        label: 'Suivi',
      ),
    ];

    return Scaffold(
      extendBody: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'CoachNutri',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ton assistant nutrition 100% personnalisé',
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Mon profil',
                    onPressed: () => _openProfile(context),
                    icon: CircleAvatar(
                      radius: 20,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? Text(
                              initials,
                              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ColoredBox(
        color: theme.colorScheme.surface,
        child: SafeArea(top: false, child: _buildBody()),
      ),
      bottomNavigationBar: BlurredNavBar(
        selectedIndex: _currentIndex,
        destinations: destinations,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }

  Widget _buildBody() {
    final padding = _currentIndex == 1
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.fromLTRB(20, 16, 20, 8);
    return Padding(
      padding: padding,
      child: IndexedStack(index: _currentIndex, children: _pages),
    );
  }

  void _onDestinationSelected(int index) {
    if (index == _currentIndex) {
      return;
    }
    Logger.i('NAVIGATION', 'Bottom tab changed from $_currentIndex to $index');
    setState(() {
      _currentIndex = index;
    });
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const IdentityPage()),
    );
  }
}
