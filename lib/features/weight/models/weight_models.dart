enum WeightRange { day, week, month, year }

enum WeightAggregate { latest, avg }

enum WeightEntrySource { manual, ai, import, aggregated }

class WeightAggregatedMeta {
  const WeightAggregatedMeta({required this.mode, required this.sampleSize});

  final String mode;
  final int sampleSize;

  factory WeightAggregatedMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const WeightAggregatedMeta(mode: 'latest', sampleSize: 1);
    }
    return WeightAggregatedMeta(
      mode: (json['mode'] as String? ?? 'latest').toLowerCase(),
      sampleSize: (json['sampleSize'] as num?)?.toInt() ?? 1,
    );
  }
}

class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.source,
    this.aggregated,
    this.isPending = false,
  });

  final String id;
  final DateTime date;
  final double weightKg;
  final String? note;
  final WeightEntrySource? source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final WeightAggregatedMeta? aggregated;
  final bool isPending;

  bool get isAggregated => aggregated != null && aggregated!.mode != 'latest';

  WeightEntry copyWith({
    String? id,
    DateTime? date,
    double? weightKg,
    String? note,
    WeightEntrySource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
    WeightAggregatedMeta? aggregated,
    bool? isPending,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      note: note ?? this.note,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      aggregated: aggregated ?? this.aggregated,
      isPending: isPending ?? this.isPending,
    );
  }

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    final aggregated = json['aggregated'];
    return WeightEntry(
      id: (json['id'] as String? ?? '').isEmpty ? 'unknown' : (json['id'] as String),
      date: DateTime.parse(json['date'] as String),
      weightKg: (json['weightKg'] as num).toDouble(),
      note: json['note'] as String?,
      source: _parseSource(json['source'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String? ?? json['date'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ?? json['date'] as String),
      aggregated: aggregated is Map<String, dynamic>
          ? WeightAggregatedMeta.fromJson(aggregated)
          : null,
    );
  }

  static WeightEntrySource? _parseSource(String? raw) {
    if (raw == null) return null;
    switch (raw.toUpperCase()) {
      case 'MANUAL':
        return WeightEntrySource.manual;
      case 'AI':
        return WeightEntrySource.ai;
      case 'IMPORT':
        return WeightEntrySource.import;
      case 'AGGREGATED':
        return WeightEntrySource.aggregated;
      default:
        return null;
    }
  }
}

class WeightStats {
  const WeightStats({this.latest, this.min, this.max, this.average});

  final double? latest;
  final double? min;
  final double? max;
  final double? average;

  factory WeightStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WeightStats();
    double? _toDouble(dynamic value) => value is num ? value.toDouble() : null;
    return WeightStats(
      latest: _toDouble(json['latest']),
      min: _toDouble(json['min']),
      max: _toDouble(json['max']),
      average: _toDouble(json['average']),
    );
  }

  WeightStats copyWith({
    double? latest,
    double? min,
    double? max,
    double? average,
  }) {
    return WeightStats(
      latest: latest ?? this.latest,
      min: min ?? this.min,
      max: max ?? this.max,
      average: average ?? this.average,
    );
  }

  static WeightStats fromEntries(List<WeightEntry> entries) {
    if (entries.isEmpty) return const WeightStats();
    final sorted = entries.toList()..sort((a, b) => a.date.compareTo(b.date));
    final weights = sorted.map((e) => e.weightKg).toList();
    final latest = sorted.last.weightKg;
    final min = weights.reduce((value, element) => value < element ? value : element);
    final max = weights.reduce((value, element) => value > element ? value : element);
    final average = weights.reduce((a, b) => a + b) / weights.length;
    return WeightStats(latest: latest, min: min, max: max, average: average);
  }
}

class WeightMeta {
  const WeightMeta({
    required this.start,
    required this.end,
    required this.totalRaw,
    required this.totalReturned,
  });

  final DateTime start;
  final DateTime end;
  final int totalRaw;
  final int totalReturned;

  factory WeightMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      final now = DateTime.now().toUtc();
      return WeightMeta(start: now, end: now, totalRaw: 0, totalReturned: 0);
    }
    return WeightMeta(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      totalRaw: (json['totalRaw'] as num?)?.toInt() ?? 0,
      totalReturned: (json['totalReturned'] as num?)?.toInt() ?? 0,
    );
  }

  WeightMeta copyWith({
    DateTime? start,
    DateTime? end,
    int? totalRaw,
    int? totalReturned,
  }) {
    return WeightMeta(
      start: start ?? this.start,
      end: end ?? this.end,
      totalRaw: totalRaw ?? this.totalRaw,
      totalReturned: totalReturned ?? this.totalReturned,
    );
  }
}

class WeightDataset {
  const WeightDataset({
    required this.range,
    required this.aggregate,
    required this.entries,
    required this.stats,
    required this.meta,
    this.fromCache = false,
  });

  final WeightRange range;
  final WeightAggregate aggregate;
  final List<WeightEntry> entries;
  final WeightStats stats;
  final WeightMeta meta;
  final bool fromCache;

  bool get hasEntries => entries.isNotEmpty;

  WeightDataset copyWith({
    List<WeightEntry>? entries,
    WeightStats? stats,
    WeightMeta? meta,
    bool? fromCache,
  }) {
    return WeightDataset(
      range: range,
      aggregate: aggregate,
      entries: entries ?? this.entries,
      stats: stats ?? this.stats,
      meta: meta ?? this.meta,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  factory WeightDataset.fromJson(Map<String, dynamic> json) {
    final range = _parseRange(json['range'] as String? ?? 'week');
    final aggregate = _parseAggregate(json['aggregate'] as String? ?? 'latest');
    final entries = ((json['entries'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WeightEntry.fromJson)
        .toList(growable: false);
    return WeightDataset(
      range: range,
      aggregate: aggregate,
      entries: entries,
      stats: WeightStats.fromJson(json['stats'] as Map<String, dynamic>?),
      meta: WeightMeta.fromJson(json['meta'] as Map<String, dynamic>?),
      fromCache: json['cached'] == true,
    );
  }
}

WeightRange _parseRange(String raw) {
  switch (raw.toLowerCase()) {
    case 'day':
    case 'jour':
      return WeightRange.day;
    case 'month':
    case 'mois':
      return WeightRange.month;
    case 'year':
    case 'annee':
      return WeightRange.year;
    default:
      return WeightRange.week;
  }
}

WeightAggregate _parseAggregate(String raw) {
  switch (raw.toLowerCase()) {
    case 'avg':
    case 'average':
    case 'moyenne':
      return WeightAggregate.avg;
    default:
      return WeightAggregate.latest;
  }
}

extension WeightRangeLabel on WeightRange {
  String get label {
    switch (this) {
      case WeightRange.day:
        return 'Jour';
      case WeightRange.week:
        return 'Semaine';
      case WeightRange.month:
        return 'Mois';
      case WeightRange.year:
        return 'Année';
    }
  }

  String get queryValue {
    switch (this) {
      case WeightRange.day:
        return 'day';
      case WeightRange.week:
        return 'week';
      case WeightRange.month:
        return 'month';
      case WeightRange.year:
        return 'year';
    }
  }
}

extension WeightAggregateLabel on WeightAggregate {
  String get queryValue => this == WeightAggregate.latest ? 'latest' : 'avg';
}

String weightRangeDisplayDate(WeightRange range, DateTime date) {
  final local = date.toLocal();
  switch (range) {
    case WeightRange.day:
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    case WeightRange.week:
      return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
    case WeightRange.month:
      return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
    case WeightRange.year:
      return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }
}

String dayKeyUtc(DateTime date) {
  final utc = date.toUtc();
  final y = utc.year.toString().padLeft(4, '0');
  final m = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
