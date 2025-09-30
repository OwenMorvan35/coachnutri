import 'package:flutter/material.dart';

import '../../core/logger.dart';
import 'widgets/weight_chart.dart';

/// Page allowing users to visualise weight evolution with filtering options.
class WeightPage extends StatefulWidget {
  const WeightPage({super.key});

  @override
  State<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  late final List<_WeightEntry> _entries;

  static const Map<int, String> _monthNames = <int, String>{
    1: 'Janvier',
    2: 'Février',
    3: 'Mars',
    4: 'Avril',
    5: 'Mai',
    6: 'Juin',
    7: 'Juillet',
    8: 'Août',
    9: 'Septembre',
    10: 'Octobre',
    11: 'Novembre',
    12: 'Décembre',
  };

  late int _selectedYear;
  int? _selectedMonth;

  @override
  void initState() {
    super.initState();
    Logger.i('WEIGHT_PAGE', 'WeightPage initState');
    _entries = _seedEntries();
    final latestEntry = _entries.reduce(
      (current, next) => next.date.isAfter(current.date) ? next : current,
    );
    _selectedYear = latestEntry.date.year;
    _selectedMonth = latestEntry.date.month;
  }

  @override
  void dispose() {
    Logger.i('WEIGHT_PAGE', 'WeightPage dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredEntries();
    final chartData = _chartEntriesLastYear();

    return Column(
      children: [
        _buildHeaderCard(theme),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildFiltersCard(theme),
              const SizedBox(height: 16),
              _buildChartCard(theme, chartData),
              const SizedBox(height: 16),
              _buildHistoryCard(theme, filtered),
              const SizedBox(height: 90),
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(top: 8, bottom: 8),
          child: FilledButton.icon(
            onPressed: () => _showAddWeightDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle mesure'),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    final latest = _entries.isNotEmpty ? _entries.last : null;
    final latestWeight = latest?.weight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF8338EC), Color(0xFFFFBE0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A8338EC),
            offset: Offset(0, 16),
            blurRadius: 32,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.monitor_weight_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suivi du poids',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  latestWeight != null
                      ? 'Dernière mesure : ${latestWeight.toStringAsFixed(1)} kg'
                      : 'Ajoute ta première mesure pour suivre ta progression.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtrer mes mesures', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(ThemeData theme, List<_WeightEntry> chartData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tendance sur 12 mois', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: WeightChart(
                points: chartData
                    .map(
                      (entry) => WeightPoint(
                        date: entry.date,
                        weight: entry.weight,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(ThemeData theme, List<_WeightEntry> entries) {
    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.insights_outlined, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Aucune mesure pour cette période',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Enregistre ton poids pour visualiser ta progression.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            for (final entry in entries)
              ListTile(
                leading: Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.trending_up_rounded, color: theme.colorScheme.primary),
                ),
                title: Text(
                  '${entry.weight.toStringAsFixed(1)} kg',
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Text(
                  _formatDate(entry.date),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final availableYears = _entries.map((e) => e.date.year).toSet().toList()
      ..sort();
    final availableMonths = _entries
        .where((entry) => entry.date.year == _selectedYear)
        .map((entry) => entry.date.month)
        .toSet()
        .toList()
      ..sort();
    final selectedYear = availableYears.contains(_selectedYear) && availableYears.isNotEmpty
        ? _selectedYear
        : (availableYears.isNotEmpty ? availableYears.last : _selectedYear);
    final selectedMonth = (_selectedMonth != null && availableMonths.contains(_selectedMonth))
        ? _selectedMonth
        : null;

    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Année', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: selectedYear,
                  underline: const SizedBox.shrink(),
                  items: availableYears
                      .map(
                        (year) => DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    Logger.i('WEIGHT_FILTER', 'Year changed to $value');
                    setState(() {
                      _selectedYear = value;
                      if (!_hasEntriesForMonth(value, _selectedMonth)) {
                        _selectedMonth = null;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mois', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: selectedMonth,
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Année complète'),
                    ),
                    ...availableMonths.map(
                      (month) => DropdownMenuItem<int?>(
                        value: month,
                        child: Text(_monthNames[month] ?? 'Mois $month'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    Logger.i('WEIGHT_FILTER', 'Month changed to ${value ?? 'full year'}');
                    setState(() {
                      _selectedMonth = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_WeightEntry> _filteredEntries() {
    final filtered = _entries.where((entry) {
      final matchesYear = entry.date.year == _selectedYear;
      final matchesMonth = _selectedMonth == null || entry.date.month == _selectedMonth;
      return matchesYear && matchesMonth;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  List<_WeightEntry> _chartEntriesLastYear() {
    if (_entries.isEmpty) {
      return const [];
    }
    final latest = _entries.reduce(
      (current, next) => next.date.isAfter(current.date) ? next : current,
    );
    final start = DateTime(latest.date.year, latest.date.month - 11, 1);

    // Precompute monthly averages for all recorded months.
    final grouped = <String, List<_WeightEntry>>{};
    for (final entry in _entries) {
      final key = '${entry.date.year}-${entry.date.month}';
      grouped.putIfAbsent(key, () => <_WeightEntry>[]).add(entry);
    }

    final List<_WeightEntry> points = <_WeightEntry>[];
    double? lastKnownWeight;

    // Determine last known weight before the start range to keep continuity.
    final previous = _entries
        .where((entry) => entry.date.isBefore(start))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (previous.isNotEmpty) {
      lastKnownWeight = previous.first.weight;
    }

    for (var i = 0; i < 12; i++) {
      final monthDate = DateTime(start.year, start.month + i, 15);
      final key = '${monthDate.year}-${monthDate.month}';
      final monthlyEntries = grouped[key];
      if (monthlyEntries != null && monthlyEntries.isNotEmpty) {
        final avgWeight = monthlyEntries
                .map((entry) => entry.weight)
                .reduce((value, element) => value + element) /
            monthlyEntries.length;
        lastKnownWeight = avgWeight;
      }

      if (lastKnownWeight != null) {
        points.add(
          _WeightEntry(date: monthDate, weight: double.parse(lastKnownWeight.toStringAsFixed(1))),
        );
      }
    }

    return points;
  }

  bool _hasEntriesForMonth(int year, int? month) {
    if (month == null) {
      return true;
    }
    return _entries.any((entry) => entry.date.year == year && entry.date.month == month);
  }

  List<_WeightEntry> _seedEntries() {
    final now = DateTime.now();
    final List<_WeightEntry> generated = <_WeightEntry>[];
    var currentWeight = 75.0;
    final randomFluctuations = <double>[0.0, -0.4, -0.2, -0.5, 0.1, -0.3, 0.0, -0.6, -0.2, -0.4, -0.1, -0.3];
    for (var i = 11; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 15);
      currentWeight += randomFluctuations[11 - i];
      generated.add(
        _WeightEntry(
          date: date,
          weight: double.parse(currentWeight.toStringAsFixed(1)),
        ),
      );
    }
    return generated;
  }

  Future<void> _showAddWeightDialog(BuildContext dialogContext) async {
    final controller = TextEditingController();
    Logger.i('WEIGHT_ADD', 'Open add weight dialog');
    final result = await showDialog<String>(
      context: dialogContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter un poids'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Ex: 71.5'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted) {
      return;
    }

    if (result == null) {
      Logger.i('WEIGHT_ADD', 'Dialog cancelled');
      return;
    }

    final parsed = double.tryParse(result.replaceAll(',', '.'));
    if (parsed == null) {
      Logger.w('WEIGHT_ADD', 'Invalid weight input: $result');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valeur invalide. Utilise un nombre.')),
      );
      return;
    }

    final newEntry = _WeightEntry(date: DateTime.now(), weight: parsed);
    setState(() {
      _entries.insert(0, newEntry);
      _selectedYear = newEntry.date.year;
      _selectedMonth = newEntry.date.month;
    });
    Logger.i('WEIGHT_ADD', 'Added new weight: ${parsed.toStringAsFixed(1)} kg');
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

class _WeightEntry {
  const _WeightEntry({required this.date, required this.weight});

  final DateTime date;
  final double weight;
}
