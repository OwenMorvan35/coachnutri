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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: tokens.blurStrong, sigmaY: tokens.blurStrong),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.glassTint,
            borderRadius: BorderRadius.circular(r),
            boxShadow: [
              BoxShadow(
                color: tokens.shadowColor,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Subtle inner top highlight
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.18),
                          Colors.white.withOpacity(0.02),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding ?? const EdgeInsets.all(12), child: child),
            ],
          ),
        ),
      ),
    );
  }
}
