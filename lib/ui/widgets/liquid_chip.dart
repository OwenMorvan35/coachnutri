import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class LiquidChip extends StatelessWidget {
  const LiquidChip({super.key, required this.label, this.selected = false, this.disabled = false, this.onTap});

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<GlassTokens>()!;
    final color = selected ? tokens.accentPrimary : tokens.textSecondary;
    final bg = Colors.white.withOpacity(selected ? 0.5 : 0.35);
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
