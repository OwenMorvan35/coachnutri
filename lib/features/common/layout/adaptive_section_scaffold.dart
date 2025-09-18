import 'package:flutter/material.dart';

class AdaptiveSectionScaffold extends StatelessWidget {
  const AdaptiveSectionScaffold({
    super.key,
    required this.hero,
    required this.body,
    this.action,
  });

  final Widget hero;
  final Widget body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;

        if (isWide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          hero,
                          if (action != null) const SizedBox(height: 20),
                          if (action != null) action!,
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(flex: 7, child: body),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            hero,
            const SizedBox(height: 16),
            Expanded(child: body),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        );
      },
    );
  }
}
