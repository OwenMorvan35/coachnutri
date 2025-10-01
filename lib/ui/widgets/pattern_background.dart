import 'package:flutter/material.dart';

class PatternBackground extends StatelessWidget {
  const PatternBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFEF9F1),
        image: DecorationImage(
          image: AssetImage('assets/images/pattern_background.png'),
          repeat: ImageRepeat.repeat,
          alignment: Alignment.topLeft,
        ),
      ),
      child: child,
    );
  }
}
