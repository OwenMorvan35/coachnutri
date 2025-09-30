import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/weight_models.dart';

class WeightChart extends StatefulWidget {
  const WeightChart({
    super.key,
    required this.entries,
    required this.range,
    this.onEntryFocus,
    this.highlighted,
  });

  final List<WeightEntry> entries;
  final WeightRange range;
  final ValueChanged<WeightEntry?>? onEntryFocus;
  final WeightEntry? highlighted;

  @override
  State<WeightChart> createState() => _WeightChartState();
}

class _WeightChartState extends State<WeightChart> {
  int? _highlightIndex;

  @override
  void initState() {
    super.initState();
    if (widget.entries.isNotEmpty) {
      _highlightIndex = widget.entries.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onEntryFocus?.call(widget.entries.last);
      });
    }
  }

  @override
  void didUpdateWidget(covariant WeightChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_didEntriesChange(oldWidget.entries, widget.entries)) {
      if (widget.entries.isEmpty) {
        _highlightIndex = null;
      } else {
        _highlightIndex = widget.entries.length - 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onEntryFocus?.call(widget.entries.last);
        });
      }
    } else if (widget.highlighted != null) {
      final idx = widget.entries.indexWhere((entry) => entry.id == widget.highlighted!.id);
      if (idx != -1 && idx != _highlightIndex) {
        setState(() => _highlightIndex = idx);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final geometry = _computeGeometry(widget.entries, size, widget.range);
        final highlightIndex = _highlightIndex != null && _highlightIndex! < geometry.points.length
            ? _highlightIndex!
            : geometry.points.length - 1;
        final highlightPoint = geometry.points[highlightIndex];

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) => _handleInteraction(details.localPosition, geometry),
          onHorizontalDragUpdate: (details) => _handleInteraction(details.localPosition, geometry),
          onPanUpdate: (details) => _handleInteraction(details.localPosition, geometry),
          child: Stack(
            children: [
              CustomPaint(
                size: size,
                painter: _WeightChartPainter(
                  geometry: geometry,
                  highlightIndex: highlightIndex,
                  range: widget.range,
                  theme: Theme.of(context),
                ),
              ),
              Positioned(
                left: _tooltipLeft(highlightPoint.offset.dx, size.width),
                top: math.max(8, highlightPoint.offset.dy - 48),
                child: _ChartTooltip(
                  weight: highlightPoint.entry.weightKg,
                  dateLabel: _tooltipLabel(widget.range, highlightPoint.entry.date),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleInteraction(Offset position, _ChartGeometry geometry) {
    if (geometry.points.isEmpty) return;
    final closest = _findClosestPoint(position, geometry.points);
    if (closest == null) return;
    if (_highlightIndex == closest) return;
    setState(() => _highlightIndex = closest);
    widget.onEntryFocus?.call(geometry.points[closest].entry);
  }

  int? _findClosestPoint(Offset position, List<_ChartPoint> points) {
    double bestDistance = double.infinity;
    int? bestIndex;
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final distance = (point.offset.dx - position.dx).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  bool _didEntriesChange(List<WeightEntry> previous, List<WeightEntry> current) {
    if (previous.length != current.length) return true;
    for (var i = 0; i < current.length; i++) {
      if (previous[i].id != current[i].id || previous[i].date != current[i].date) {
        return true;
      }
    }
    return false;
  }

  double _tooltipLeft(double x, double width) {
    const tooltipWidth = 120.0;
    final candidate = x - tooltipWidth / 2;
    return candidate.clamp(8.0, width - tooltipWidth - 8.0);
  }
}

class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter({
    required this.geometry,
    required this.highlightIndex,
    required this.range,
    required ThemeData theme,
  })  : axisColor = theme.colorScheme.onSurface.withOpacity(0.4),
        gridColor = theme.colorScheme.onSurface.withOpacity(0.12),
        textColor = theme.colorScheme.onSurface.withOpacity(0.78),
        lineColor = theme.colorScheme.primary,
        fillColor = theme.colorScheme.primary.withOpacity(0.15),
        highlightColor = theme.colorScheme.secondary;

  final _ChartGeometry geometry;
  final int highlightIndex;
  final WeightRange range;
  final Color axisColor;
  final Color gridColor;
  final Color textColor;
  final Color lineColor;
  final Color fillColor;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final padding = geometry.padding;
    final chartRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      geometry.chartWidth,
      geometry.chartHeight,
    );

    final backgroundPaint = Paint()
      ..color = lineColor.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(chartRect, const Radius.circular(18)),
      backgroundPaint,
    );

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Axes
    canvas.drawLine(
      Offset(padding.left, size.height - padding.bottom),
      Offset(padding.left, padding.top),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padding.left, size.height - padding.bottom),
      Offset(size.width - padding.right, size.height - padding.bottom),
      axisPaint,
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const ySteps = 4;
    for (var i = 0; i <= ySteps; i++) {
      final ratio = i / ySteps;
      final y = geometry.bottom - geometry.chartHeight * ratio;
      canvas.drawLine(
        Offset(padding.left, y),
        Offset(size.width - padding.right, y),
        gridPaint,
      );
      final value = geometry.minWeight + (geometry.rangeWeight * ratio);
      textPainter
        ..text = TextSpan(
          text: value.toStringAsFixed(1).replaceAll('.', ','),
          style: TextStyle(fontSize: 11, color: textColor),
        )
        ..layout();
      textPainter.paint(
        canvas,
        Offset(padding.left - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    final path = Path();
    final fill = Path();
    for (var i = 0; i < geometry.points.length; i++) {
      final point = geometry.points[i];
      final offset = point.offset;
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
        fill.moveTo(offset.dx, geometry.bottom);
        fill.lineTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
        fill.lineTo(offset.dx, offset.dy);
      }
    }

    fill.lineTo(geometry.points.last.offset.dx, geometry.bottom);
    fill.close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fill, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Draw points
    for (var i = 0; i < geometry.points.length; i++) {
      final point = geometry.points[i];
      final paint = Paint()
        ..color = i == highlightIndex ? highlightColor : lineColor
        ..style = PaintingStyle.fill;
      final double radius = i == highlightIndex ? 5.2 : 4.0;
      canvas.drawCircle(point.offset, radius, paint);
    }

    // X labels
    final labels = _resolveLabelPoints(geometry.points, range);
    for (final label in labels) {
      textPainter
        ..text = TextSpan(
          text: label.text,
          style: TextStyle(fontSize: 11, color: textColor),
        )
        ..layout();
      final dx = label.offset.dx - textPainter.width / 2;
      final dy = geometry.bottom + 8;
      textPainter.paint(canvas, Offset(dx.clamp(padding.left, size.width - padding.right - textPainter.width), dy));
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) {
    return oldDelegate.geometry != geometry || oldDelegate.highlightIndex != highlightIndex;
  }

  List<_LabelPoint> _resolveLabelPoints(List<_ChartPoint> points, WeightRange range) {
    if (points.isEmpty) return const [];
    final indexes = <int>{0, points.length - 1};
    if (points.length > 2) {
      indexes.add(points.length ~/ 2);
    }
    return indexes.map((index) {
      final point = points[index];
      return _LabelPoint(
        offset: point.offset,
        text: _axisLabel(range, point.entry.date),
      );
    }).toList();
  }
}

class _ChartTooltip extends StatelessWidget {
  const _ChartTooltip({required this.weight, required this.dateLabel});

  final double weight;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 6)),
        ],
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${weight.toStringAsFixed(1).replaceAll('.', ',')} kg',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            dateLabel,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LabelPoint {
  const _LabelPoint({required this.offset, required this.text});

  final Offset offset;
  final String text;
}

class _ChartPoint {
  const _ChartPoint({required this.entry, required this.offset});

  final WeightEntry entry;
  final Offset offset;
}

class _ChartGeometry {
  const _ChartGeometry({
    required this.points,
    required this.minWeight,
    required this.maxWeight,
    required this.minDate,
    required this.maxDate,
    required this.padding,
    required this.chartWidth,
    required this.chartHeight,
  });

  final List<_ChartPoint> points;
  final double minWeight;
  final double maxWeight;
  final DateTime minDate;
  final DateTime maxDate;
  final EdgeInsets padding;
  final double chartWidth;
  final double chartHeight;

  double get bottom => padding.top + chartHeight;
  double get rangeWeight => maxWeight - minWeight;
}

_ChartGeometry _computeGeometry(List<WeightEntry> entries, Size size, WeightRange range) {
  final sorted = entries.toList()..sort((a, b) => a.date.compareTo(b.date));
  const padding = EdgeInsets.fromLTRB(54, 24, 24, 36);
  final chartWidth = math.max(10.0, size.width - padding.left - padding.right);
  final chartHeight = math.max(10.0, size.height - padding.top - padding.bottom);

  double minWeight = sorted.map((e) => e.weightKg).reduce(math.min);
  double maxWeight = sorted.map((e) => e.weightKg).reduce(math.max);
  final spread = (maxWeight - minWeight).abs();
  if (spread < 0.5) {
    minWeight -= 0.8;
    maxWeight += 0.8;
  } else {
    final extra = spread * 0.1;
    minWeight -= extra;
    maxWeight += extra;
  }

  final minDate = sorted.first.date;
  final maxDate = sorted.last.date;
  final hasSpan = maxDate.isAfter(minDate);
  final totalMs = hasSpan
      ? (maxDate.millisecondsSinceEpoch - minDate.millisecondsSinceEpoch).toDouble()
      : 1.0;

  final points = <_ChartPoint>[];
  for (final entry in sorted) {
    final ms = hasSpan
        ? (entry.date.millisecondsSinceEpoch - minDate.millisecondsSinceEpoch).toDouble()
        : totalMs / 2;
    final ratioX = hasSpan ? (ms / totalMs) : 0.5;
    final dx = padding.left + chartWidth * ratioX;

    final ratioY = ((entry.weightKg - minWeight) / (maxWeight - minWeight)).clamp(0.0, 1.0);
    final dy = padding.top + chartHeight * (1 - ratioY);
    points.add(_ChartPoint(entry: entry, offset: Offset(dx, dy)));
  }

  return _ChartGeometry(
    points: points,
    minWeight: minWeight,
    maxWeight: maxWeight,
    minDate: minDate,
    maxDate: maxDate,
    padding: padding,
    chartWidth: chartWidth,
    chartHeight: chartHeight,
  );
}

String _tooltipLabel(WeightRange range, DateTime date) {
  final local = date.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  switch (range) {
    case WeightRange.day:
      return '$day/$month • $hh:$mm';
    case WeightRange.week:
      return '$day/$month • $hh:$mm';
    case WeightRange.month:
    case WeightRange.year:
      return '$day/$month/${local.year} • $hh:$mm';
  }
}

String _axisLabel(WeightRange range, DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  switch (range) {
    case WeightRange.day:
      final hh = local.hour.toString().padLeft(2, '0');
      return '$hh:${local.minute.toString().padLeft(2, '0')}';
    case WeightRange.week:
      const labels = <int, String>{
        DateTime.monday: 'Lu',
        DateTime.tuesday: 'Ma',
        DateTime.wednesday: 'Me',
        DateTime.thursday: 'Je',
        DateTime.friday: 'Ve',
        DateTime.saturday: 'Sa',
        DateTime.sunday: 'Di',
      };
      final prefix = labels[local.weekday] ?? '';
      return '$prefix $day';
    case WeightRange.month:
      return '$day/$month';
    case WeightRange.year:
      return '$month/${local.year.toString().substring(2)}';
  }
}
