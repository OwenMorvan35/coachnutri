import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/logger.dart';
import '../../core/session.dart';
import 'models/weight_models.dart';
import 'services/weight_api.dart';
import 'services/weight_repository.dart';
import 'widgets/add_weight_sheet.dart';
import 'widgets/weight_chart.dart';

class WeightPage extends StatefulWidget {
  const WeightPage({super.key});

  @override
  State<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  late final WeightApi _api;
  final Map<WeightRange, bool> _loadingRanges = {
    WeightRange.day: false,
    WeightRange.week: false,
    WeightRange.month: false,
    WeightRange.year: false,
  };

  WeightRange _selectedRange = WeightRange.week;
  WeightDataset? _dataset;
  WeightEntry? _highlighted;
  bool _loading = true;
  String? _error;
  StreamSubscription<WeightDataset>? _subscription;

  @override
  void initState() {
    super.initState();
    final sessionController = SessionScope.of(context, listen: false);
    _api = WeightApi(tokenProvider: () => sessionController.session?.token);
    _listenToRange(_selectedRange);
    unawaited(_loadRange(_selectedRange, force: true));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _api.dispose();
    super.dispose();
  }

  void _listenToRange(WeightRange range) {
    _subscription?.cancel();
    _subscription = WeightRepository.instance.watch(range).listen((dataset) {
      if (!mounted) return;
      Logger.i('WEIGHT_STREAM', 'Dataset update for ${range.name}: ${dataset.entries.length} points');
      setState(() {
        _dataset = dataset;
        _loading = false;
        _error = null;
        _highlighted = dataset.entries.isNotEmpty ? dataset.entries.last : null;
      });
    });

    final cached = WeightRepository.instance.getDataset(range);
    _dataset = cached;
    _loading = cached == null;
    _error = null;
    _highlighted = cached?.entries.isNotEmpty ?? false ? cached!.entries.last : null;
  }

  Future<void> _loadRange(WeightRange range, {bool force = false}) async {
    if (_loadingRanges[range] == true) return;
    final cached = WeightRepository.instance.getDataset(range);
    if (!force && cached != null) {
      if (range == _selectedRange && mounted) {
        setState(() {
          _dataset = cached;
          _loading = false;
          _error = null;
          _highlighted = cached.entries.isNotEmpty ? cached.entries.last : null;
        });
      }
      return;
    }

    _loadingRanges[range] = true;
    if (range == _selectedRange && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final dataset = await _api.fetchRange(range: range);
      WeightRepository.instance.setDataset(dataset);
    } on WeightApiException catch (error) {
      if (range == _selectedRange && mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (error) {
      if (range == _selectedRange && mounted) {
        setState(() {
          _error = 'Impossible de charger les mesures.';
          _loading = false;
        });
      }
    } finally {
      _loadingRanges[range] = false;
    }
  }

  Future<void> _handleRefresh() => _loadRange(_selectedRange, force: true);

  void _onRangeChanged(WeightRange range) {
    if (_selectedRange == range) return;
    _selectedRange = range;
    _listenToRange(range);
    if (mounted) {
      setState(() {
        _dataset = WeightRepository.instance.getDataset(range);
        _loading = _dataset == null;
        _error = null;
        _highlighted = _dataset?.entries.isNotEmpty ?? false ? _dataset!.entries.last : null;
      });
    }
    unawaited(_loadRange(range));
  }

  Future<void> _handleAddWeight() async {
    final result = await AddWeightSheet.show(context);
    if (result == null) return;

    final measurementDate = result.date.toUtc();
    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = WeightEntry(
      id: tempId,
      date: measurementDate,
      weightKg: result.weightKg,
      note: result.note,
      source: WeightEntrySource.manual,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      isPending: true,
    );

    WeightRepository.instance.addOptimisticEntry(optimistic);
    if (mounted) {
      setState(() {
        _highlighted = optimistic;
      });
    }

    try {
      final confirmed = await _api.createEntry(
        weightKg: result.weightKg,
        date: measurementDate,
        note: result.note,
      );
      WeightRepository.instance.replaceEntry(tempId, confirmed);
      if (mounted) {
        setState(() {
          _highlighted = confirmed;
        });
      }
      await _loadRange(_selectedRange, force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesure enregistrée.')),
      );
    } on WeightApiException catch (error) {
      WeightRepository.instance.removeEntry(tempId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      WeightRepository.instance.removeEntry(tempId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enregistrement impossible. Vérifie ta connexion.')),
      );
    }
  }

  void _handleHighlight(WeightEntry? entry) {
    if (!mounted) return;
    setState(() => _highlighted = entry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            child: _buildScrollable(theme),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter mon poids'),
              onPressed: _handleAddWeight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollable(ThemeData theme) {
    if (_loading && _dataset == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _buildHeaderCard(theme),
          const SizedBox(height: 16),
          _buildRangeSelector(theme),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _loadRange(_selectedRange, force: true),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final entries = _dataset?.entries ?? const <WeightEntry>[];
    final stats = _dataset?.stats ?? const WeightStats();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _buildHeaderCard(theme),
        const SizedBox(height: 16),
        _buildRangeSelector(theme),
        const SizedBox(height: 16),
        _buildChartCard(theme, entries),
        const SizedBox(height: 16),
        _buildStatsRow(theme, stats),
        const SizedBox(height: 16),
        _buildHistory(theme, entries),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    final lastEntry = _dataset?.entries.isNotEmpty ?? false ? _dataset!.entries.last : null;
    final latestWeight = lastEntry?.weightKg;
    final subtitle = latestWeight != null
        ? 'Dernière mesure le ${_formatFullDate(lastEntry!.date)}'
        : 'Ajoute ta première mesure pour démarrer le suivi.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            offset: Offset(0, 18),
            blurRadius: 32,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.monitor_weight_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  latestWeight != null ? '${_formatWeight(latestWeight)} kg' : 'Suivi du poids',
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Période', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<WeightRange>(
              segments: [
                for (final range in WeightRange.values)
                  ButtonSegment<WeightRange>(
                    value: range,
                    label: Text(range.label),
                  ),
              ],
              selected: <WeightRange>{_selectedRange},
              onSelectionChanged: (selection) => _onRangeChanged(selection.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(ThemeData theme, List<WeightEntry> entries) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progression', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: entries.isEmpty
                  ? const Center(child: Text('Aucune donnée pour cette période.'))
                  : WeightChart(
                      entries: entries,
                      range: _selectedRange,
                      highlighted: _highlighted,
                      onEntryFocus: _handleHighlight,
                    ),
            ),
            if (_highlighted != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_formatFullDate(_highlighted!.date)} • ${_formatWeight(_highlighted!.weightKg)} kg',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme, WeightStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            _buildStatTile(theme, 'Dernier', stats.latest),
            _buildDivider(),
            _buildStatTile(theme, 'Minimum', stats.min),
            _buildDivider(),
            _buildStatTile(theme, 'Maximum', stats.max),
            _buildDivider(),
            _buildStatTile(theme, 'Moyenne', stats.average),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(ThemeData theme, String label, double? value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value != null ? '${_formatWeight(value)} kg' : '--',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => SizedBox(
        height: 40,
        child: VerticalDivider(color: Colors.grey.withOpacity(0.3)),
      );

  Widget _buildHistory(ThemeData theme, List<WeightEntry> entries) {
    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_chart_outlined, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Aucune mesure pour cette période',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Ajoute un poids ou demande au coach de le faire pour toi.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: entries.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor.withOpacity(0.2)),
        itemBuilder: (context, index) {
          final entry = entries.reversed.elementAt(index);
          return ListTile(
            leading: _buildSourceAvatar(theme, entry),
            title: Text('${_formatWeight(entry.weightKg)} kg', style: theme.textTheme.titleMedium),
            subtitle: Text(_formatFullDate(entry.date)),
            trailing: entry.isPending
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
          );
        },
      ),
    );
  }

  Widget _buildSourceAvatar(ThemeData theme, WeightEntry entry) {
    final color = switch (entry.source) {
      WeightEntrySource.ai => theme.colorScheme.primary,
      WeightEntrySource.import => theme.colorScheme.tertiary,
      _ => theme.colorScheme.secondary,
    };
    final icon = switch (entry.source) {
      WeightEntrySource.ai => Icons.smart_toy_outlined,
      WeightEntrySource.import => Icons.download_done_rounded,
      _ => Icons.edit_note_rounded,
    };
    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withOpacity(0.15),
      child: Icon(icon, color: color),
    );
  }

  String _formatWeight(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

  String _formatFullDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year à $hour:$minute';
  }
}
