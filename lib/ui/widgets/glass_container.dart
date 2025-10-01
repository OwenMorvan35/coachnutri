import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

// Reusable frosted glass container with blur + subtle stroke
class GlassContainer extends StatelessWidget {
  const GlassContainer({super.key, required this.child, this.padding, this.radius});

  final Widget child;
  final EdgeInsets? padding;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<GlassTokens>()!;
    final r = radius ?? tokens.radius;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.86),
          borderRadius: BorderRadius.circular(r),
        ),
        child: Padding(padding: padding ?? const EdgeInsets.all(12), child: child),
      ),
    );
  }
}
