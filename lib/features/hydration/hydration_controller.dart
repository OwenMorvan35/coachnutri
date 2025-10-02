import 'dart:async';

import 'package:flutter/widgets.dart';

/// Provides the hydration state for the day and exposes helpers to update it.
///
/// The controller stores the consumed quantity (in millilitres) and exposes
/// convenient getters to retrieve the goal, the raw percentage (0-100+), and
/// the animation progress clamped between 0 and 1.
class HydrationController extends ChangeNotifier {
  HydrationController({int dailyGoalMl = 2000})
      : assert(dailyGoalMl > 0, 'The hydration goal must be greater than zero.'),
        _dailyGoalMl = dailyGoalMl;

  int _dailyGoalMl;
  int _consumedMl = 0;
  DateTime? _lastResetAt;
  DateTime? _updatedAt;
  DateTime? _lastIntakeAt;
  DateTime? _nextAvailableAt;
  Duration _cooldownDuration = const Duration(hours: 1);
  Timer? _cooldownTimer;

  int get dailyGoalMl => _dailyGoalMl;
  int get consumedMl => _consumedMl;
  DateTime? get lastResetAt => _lastResetAt;
  DateTime? get updatedAt => _updatedAt;
  DateTime? get lastIntakeAt => _lastIntakeAt;
  DateTime? get nextAvailableAt => _nextAvailableAt;
  Duration get cooldownDuration => _cooldownDuration;

  bool get isCooldownActive =>
      _nextAvailableAt != null && _nextAvailableAt!.isAfter(DateTime.now());

  Duration? get remainingCooldown => isCooldownActive
      ? _nextAvailableAt!.difference(DateTime.now())
      : null;

  /// Raw percentage that can exceed 100 when the user drinks more than the goal.
  double get hydrationPercent => (_consumedMl / _dailyGoalMl) * 100;

  /// Animation-friendly progress, clamped between 0 and 1.
  double get progress => (_consumedMl / _dailyGoalMl).clamp(0.0, 1.0);

  double get goalInLiters => _dailyGoalMl / 1000;
  double get consumedInLiters => _consumedMl / 1000;

  /// Resets daily consumption, handy for manual resets or when the day changes.
  void reset() {
    if (_consumedMl == 0) return;
    _consumedMl = 0;
    _lastIntakeAt = null;
    _nextAvailableAt = null;
    _cancelCooldownTimer();
    notifyListeners();
  }

  /// Sets the consumed amount directly (in millilitres).
  void setConsumed(int millilitres) {
    if (millilitres < 0) {
      _consumedMl = 0;
    } else {
      _consumedMl = millilitres;
    }
    notifyListeners();
  }

  /// Adds water to the daily total and notifies listeners.
  void addWater(int millilitres) {
    if (millilitres <= 0) return;
    _consumedMl += millilitres;
    notifyListeners();
  }

  void setDailyGoal(int millilitres) {
    if (millilitres <= 0 || millilitres == _dailyGoalMl) return;
    _dailyGoalMl = millilitres;
    notifyListeners();
  }

  /// Synchronises the controller with remote state returned by the backend.
  void applyRemoteState({
    required int consumedMl,
    required int dailyGoalMl,
    DateTime? lastResetAt,
    DateTime? updatedAt,
    DateTime? lastIntakeAt,
    DateTime? nextAvailableAt,
    int? cooldownMs,
    bool notify = true,
  }) {
    _consumedMl = consumedMl < 0 ? 0 : consumedMl;
    if (dailyGoalMl > 0) {
      _dailyGoalMl = dailyGoalMl;
    }
    _lastResetAt = lastResetAt;
    _updatedAt = updatedAt;
    _lastIntakeAt = lastIntakeAt;
    if (cooldownMs != null && cooldownMs > 0) {
      _cooldownDuration = Duration(milliseconds: cooldownMs);
    }
    if (nextAvailableAt != null) {
      _nextAvailableAt = nextAvailableAt;
    } else if (_lastIntakeAt != null) {
      final candidate = _lastIntakeAt!.add(_cooldownDuration);
      _nextAvailableAt = candidate.isAfter(DateTime.now()) ? candidate : null;
    } else {
      _nextAvailableAt = null;
    }
    _scheduleCooldownTimer();
    if (notify) notifyListeners();
  }

  void _scheduleCooldownTimer() {
    _cancelCooldownTimer();
    final target = _nextAvailableAt;
    if (target == null) {
      return;
    }
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) {
      _nextAvailableAt = null;
      return;
    }
    _cooldownTimer = Timer(diff, () {
      _nextAvailableAt = null;
      notifyListeners();
    });
  }

  void _cancelCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }

  @override
  void dispose() {
    _cancelCooldownTimer();
    super.dispose();
  }
}

/// Exposes a [HydrationController] to the widget tree using an
/// [InheritedNotifier]. Widgets can subscribe to hydration updates by calling
/// [HydrationScope.of].
class HydrationScope extends InheritedNotifier<HydrationController> {
  const HydrationScope({
    super.key,
    required HydrationController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static HydrationController of(BuildContext context, {bool listen = true}) {
    HydrationScope? scope;
    if (listen) {
      scope = context.dependOnInheritedWidgetOfExactType<HydrationScope>();
    } else {
      final element =
          context.getElementForInheritedWidgetOfExactType<HydrationScope>();
      scope = element?.widget as HydrationScope?;
    }
    if (scope == null) {
      throw StateError('HydrationScope not found in widget tree');
    }
    return scope.notifier!;
  }

  static HydrationController? maybeOf(BuildContext context,
      {bool listen = true}) {
    if (listen) {
      return context
          .dependOnInheritedWidgetOfExactType<HydrationScope>()
          ?.notifier;
    }
    final element =
        context.getElementForInheritedWidgetOfExactType<HydrationScope>();
    return (element?.widget as HydrationScope?)?.notifier;
  }

  @override
  bool updateShouldNotify(HydrationScope oldWidget) =>
      notifier != oldWidget.notifier;
}
