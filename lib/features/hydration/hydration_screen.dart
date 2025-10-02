import 'package:flutter/material.dart';

import '../../core/session.dart';
import 'hydration_api.dart';
import 'hydration_assets.dart';
import 'hydration_controller.dart';
import 'widgets/plant_widget.dart';

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen> {
  late final HydrationController _controller;
  HydrationApi? _api;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _controller = HydrationController();
  }

  @override
  void dispose() {
    _api?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api == null) {
      final session = SessionScope.of(context, listen: false);
      _api = HydrationApi(tokenProvider: () => session.session?.token);
      _loadState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HydrationScope(
      controller: _controller,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(HydrationAssets.background),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Hydratation'),
          ),
          body: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final percent = _controller.hydrationPercent;
              final goalLiters = _controller.goalInLiters;
              final consumedLiters = _controller.consumedInLiters;
              final percentLabel = percent.clamp(0, 200).toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$percentLabel% d\'hydratation',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Objectif ${goalLiters.toStringAsFixed(1)} L · Ingesté ${consumedLiters.toStringAsFixed(2)} L',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const PlantWidget(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.local_drink_rounded),
                          label: const Text('+250 ml'),
                          onPressed: () => _addIntake(250),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.water_drop_rounded),
                          label: const Text('+500 ml'),
                          onPressed: () => _addIntake(500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Les boutons ajustent le niveau et animent la plante.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _loadState() async {
    final api = _api;
    if (api == null) return;
    try {
      final hydration = await api.fetchState();
      _controller.applyRemoteState(
        consumedMl: hydration.consumedMl,
        dailyGoalMl: hydration.dailyGoalMl,
        lastResetAt: hydration.lastResetAt,
        updatedAt: hydration.updatedAt,
        lastIntakeAt: hydration.lastIntakeAt,
        nextAvailableAt: hydration.nextAvailableAt,
        cooldownMs: hydration.cooldownMs,
      );
    } on HydrationApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger l\'hydratation.')),
      );
    }
  }

  Future<void> _addIntake(int amount) async {
    if (_api == null || _updating) return;
    setState(() => _updating = true);
    try {
      final hydration = await _api!.addIntake(amount);
      _controller.applyRemoteState(
        consumedMl: hydration.consumedMl,
        dailyGoalMl: hydration.dailyGoalMl,
        lastResetAt: hydration.lastResetAt,
        updatedAt: hydration.updatedAt,
        lastIntakeAt: hydration.lastIntakeAt,
        nextAvailableAt: hydration.nextAvailableAt,
        cooldownMs: hydration.cooldownMs,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$amount ml ajoutés.')),
      );
    } on HydrationApiException catch (error) {
      if (error.hydration != null) {
        final hydration = error.hydration!;
        _controller.applyRemoteState(
          consumedMl: hydration.consumedMl,
          dailyGoalMl: hydration.dailyGoalMl,
          lastResetAt: hydration.lastResetAt,
          updatedAt: hydration.updatedAt,
          lastIntakeAt: hydration.lastIntakeAt,
          nextAvailableAt: hydration.nextAvailableAt,
          cooldownMs: hydration.cooldownMs,
        );
      }
      if (!mounted) return;
      final message = error.message.isNotEmpty
          ? error.message
          : 'Impossible d\'ajouter de l\'eau pour le moment.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ajouter de l\'eau pour le moment.')),
      );
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }
}
