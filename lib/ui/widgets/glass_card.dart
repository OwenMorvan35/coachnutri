import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'glass_container.dart';

// Glass-styled card container for sections
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, this.header, required this.child, EdgeInsets? padding})
      : _padding = padding ?? const EdgeInsets.all(12);

  final Widget? header;
  final Widget child;
  final EdgeInsets _padding;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<GlassTokens>()!;
    return GlassContainer(
      padding: EdgeInsets.zero,
      radius: tokens.radius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.titleSmall!,
                child: header!,
              ),
            ),
          Padding(padding: _padding, child: child),
        ],
      ),
    );
  }
}

