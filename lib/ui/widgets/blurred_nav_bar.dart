import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

// Floating glass bottom bar wrapping a standard NavigationBar
class BlurredNavBar extends StatelessWidget {
  const BlurredNavBar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
    this.height = 68,
  });

  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<GlassTokens>()!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radius + 4),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: tokens.blurStrong, sigmaY: tokens.blurStrong),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.glassTint,
                borderRadius: BorderRadius.circular(tokens.radius + 4),
                boxShadow: [
                  BoxShadow(color: tokens.shadowColor, blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                indicatorColor: tokens.accentPrimary.withOpacity(0.12),
                height: height,
                selectedIndex: selectedIndex,
                destinations: destinations,
                onDestinationSelected: onDestinationSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
