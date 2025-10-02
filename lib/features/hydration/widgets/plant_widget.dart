import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../hydration_controller.dart';

/// Displays the animated hydration plant and reacts to [HydrationController]
/// updates.
///
/// ```dart
/// HydrationScope(
///   controller: HydrationController(),
///   child: const PlantWidget(),
/// );
/// ```
class PlantWidget extends StatefulWidget {
  const PlantWidget({super.key});

  @override
  State<PlantWidget> createState() => _PlantWidgetState();
}

class _PlantWidgetState extends State<PlantWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  LottieComposition? _composition;
  double _lastTarget = 0;
  double? _pendingTarget;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final hydration = HydrationScope.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncProgress(hydration.progress);
    });

    return Lottie.asset(
      'assets/lottie/plant.json',
      controller: _animationController,
      fit: BoxFit.contain,
      onLoaded: (composition) {
        if (_composition == null) {
          _composition = composition;
          _animationController
            ..duration = composition.duration
            ..value = hydration.progress.clamp(0.0, 1.0);
          _lastTarget = _animationController.value;
          if (_pendingTarget != null) {
            final target = _pendingTarget!;
            _pendingTarget = null;
            _syncProgress(target, animate: true);
          }
        }
      },
    );
  }

  void _syncProgress(double target, {bool animate = true}) {
    final clamped = target.clamp(0.0, 1.0);
    if (_composition == null) {
      _pendingTarget = clamped;
      return;
    }
    if ((clamped - _lastTarget).abs() < 0.001) {
      return;
    }
    if (!animate) {
      _animationController.value = clamped;
      _lastTarget = clamped;
      return;
    }
    final diff = (clamped - _animationController.value).abs();
    final durationMs = (diff * 800).clamp(240, 900).round();
    _animationController.animateTo(
      clamped,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
    );
    _lastTarget = clamped;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
