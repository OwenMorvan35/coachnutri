import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class WaterDropButton extends StatefulWidget {
  const WaterDropButton({super.key, required this.onPressed, required this.child, this.enabled = true});

  final VoidCallback onPressed;
  final Widget child;
  final bool enabled;

  @override
  State<WaterDropButton> createState() => _WaterDropButtonState();
}

class _WaterDropButtonState extends State<WaterDropButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<GlassTokens>()!;
    final scale = _pressed ? 0.98 : 1.0;
    final gradient = tokens.oceanic;
    final disabled = !widget.enabled;
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      scale: scale,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: Opacity(
          opacity: disabled ? 0.6 : 1.0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: tokens.shadowColor, blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: Stack(
              children: [
                // Glossy specular overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.28),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Center(
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      child: IconTheme(
                        data: const IconThemeData(color: Colors.white),
                        child: GestureDetector(
                          onTap: disabled ? null : widget.onPressed,
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

