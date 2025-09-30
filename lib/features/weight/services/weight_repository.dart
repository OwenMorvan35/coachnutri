import 'dart:async';

import '../models/weight_models.dart';

class WeightRepository {
  WeightRepository._();

  static final WeightRepository instance = WeightRepository._();

  final Map<WeightRange, WeightDataset> _datasets = <WeightRange, WeightDataset>{};
  final Map<String, WeightEntry> _optimistic = <String, WeightEntry>{};
  StreamController<WeightDataset>? _controller;

  StreamController<WeightDataset> _ensureController() {
    return _controller ??= StreamController<WeightDataset>.broadcast();
  }

  Stream<WeightDataset> watch(WeightRange range) {
    return _ensureController().stream.where((dataset) => dataset.range == range);
  }

  WeightDataset? getDataset(WeightRange range) => _datasets[range];

  void setDataset(WeightDataset dataset, {bool notify = true}) {
    _datasets[dataset.range] = dataset;
    if (notify) {
      final ctrl = _ensureController();
      if (!ctrl.isClosed) ctrl.add(dataset);
    }
  }

  WeightEntry addOptimisticEntry(WeightEntry entry) {
    final pendingId = entry.id;
    final pending = entry.copyWith(isPending: true);
    _optimistic[pendingId] = pending;
    _applyEntryToDatasets(pending);
    return pending;
  }

  void replaceEntry(String tempId, WeightEntry actual) {
    _optimistic.remove(tempId);
    _updateDatasets((dataset) {
      if (dataset.aggregate != WeightAggregate.latest) {
        return dataset;
      }
      final entries = dataset.entries.toList();
      final index = entries.indexWhere((element) => element.id == tempId);
      if (index >= 0) {
        entries[index] = actual;
      } else if (_isWithinRange(dataset, actual.date)) {
        final merged = _mergeLatest(entries, actual);
        return dataset.copyWith(
          entries: merged,
          stats: WeightStats.fromEntries(merged),
          meta: dataset.meta.copyWith(totalReturned: merged.length),
        );
      } else {
        return dataset;
      }
      final cleaned = _mergeLatest(entries, actual);
      return dataset.copyWith(
        entries: cleaned,
        stats: WeightStats.fromEntries(cleaned),
        meta: dataset.meta.copyWith(totalReturned: cleaned.length),
      );
    });
  }

  void removeEntry(String id) {
    _optimistic.remove(id);
    _updateDatasets((dataset) {
      final entries = dataset.entries.where((e) => e.id != id).toList();
      return dataset.copyWith(
        entries: entries,
        stats: WeightStats.fromEntries(entries),
        meta: dataset.meta.copyWith(totalReturned: entries.length),
      );
    });
  }

  void invalidate(WeightRange range) {
    _datasets.remove(range);
  }

  void clear() {
    _datasets.clear();
    _optimistic.clear();
  }

  void applyServerEntry(WeightEntry entry) {
    _applyEntryToDatasets(entry.copyWith(isPending: false));
  }

  void _applyEntryToDatasets(WeightEntry entry) {
    _updateDatasets((dataset) {
      if (dataset.aggregate != WeightAggregate.latest) {
        return dataset;
      }
      if (!_isWithinRange(dataset, entry.date)) {
        return dataset;
      }
      final merged = _mergeLatest(dataset.entries, entry);
      return dataset.copyWith(
        entries: merged,
        stats: WeightStats.fromEntries(merged),
        meta: dataset.meta.copyWith(totalReturned: merged.length),
      );
    });
  }

  void _updateDatasets(WeightDataset Function(WeightDataset dataset) transform) {
    for (final entry in _datasets.entries.toList()) {
      final updated = transform(entry.value);
      if (!identical(updated, entry.value)) {
        _datasets[entry.key] = updated;
        final ctrl = _ensureController();
        if (!ctrl.isClosed) ctrl.add(updated);
      }
    }
  }

  bool _isWithinRange(WeightDataset dataset, DateTime date) {
    final start = dataset.meta.start;
    final end = dataset.meta.end;
    final ts = date.toUtc();
    return ts.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
        ts.isBefore(end.add(const Duration(milliseconds: 1)));
  }

  List<WeightEntry> _mergeLatest(List<WeightEntry> entries, WeightEntry incoming) {
    final list = entries.toList();
    final incomingKey = dayKeyUtc(incoming.date);
    final index = list.indexWhere((element) => dayKeyUtc(element.date) == incomingKey);
    if (index >= 0) {
      final existing = list[index];
      if (incoming.date.isAfter(existing.date) || existing.isAggregated || existing.isPending) {
        list[index] = incoming;
      } else {
        return list;
      }
    } else {
      list.add(incoming);
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }
}
