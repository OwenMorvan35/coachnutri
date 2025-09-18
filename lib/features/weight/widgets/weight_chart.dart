import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/logger.dart';

/// Stateless chart widget rendering weight evolution using a simple line graph.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.points});

  final List<WeightPoint> points;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 240,
        width: double.infinity,
        child: points.isEmpty
            ? const Center(
                child: Text('Ajoute des mesures pour visualiser le graphique.'),
              )
            : CustomPaint(
                painter: _WeightChartPainter(points: points),
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}

/// Lightweight structure representing chart data.
class WeightPoint {
  const WeightPoint({required this.date, required this.weight});

  final DateTime date;
  final double weight;
}

class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter({required this.points});

  final List<WeightPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final sorted = List<WeightPoint>.from(points)
      ..sort((a, b) => a.date.compareTo(b.date));

    final chartPadding = const EdgeInsets.fromLTRB(40, 20, 24, 32);
    final chartWidth = size.width - chartPadding.left - chartPadding.right;
    final chartHeight = size.height - chartPadding.top - chartPadding.bottom;

    if (chartWidth <= 0 || chartHeight <= 0) {
      Logger.w('WEIGHT_CHART', 'Chart size is too small to render');
      return;
    }

    final minWeight = sorted.map((p) => p.weight).reduce(min);
    final maxWeight = sorted.map((p) => p.weight).reduce(max);

    final weightRange = max(1.0, (maxWeight - minWeight).abs());
    final minDate = sorted.first.date;
    final maxDate = sorted.last.date;
    final totalDays = max(1, maxDate.difference(minDate).inDays);

    final axisPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.2;
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0;
    final linePaint = Paint()
      ..color = Colors.green.shade700
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = Colors.green.shade300.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final axisBottom = Offset(chartPadding.left, size.height - chartPadding.bottom);
    final axisTop = Offset(chartPadding.left, chartPadding.top);
    final axisRight = Offset(size.width - chartPadding.right, size.height - chartPadding.bottom);

    // Background area behind the chart for better contrast.
    final backgroundRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        chartPadding.left,
        chartPadding.top,
        chartWidth,
        chartHeight,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      backgroundRect,
      Paint()..color = Colors.green.shade50,
    );

    // Axes
    canvas.drawLine(axisBottom, axisTop, axisPaint);
    canvas.drawLine(axisBottom, axisRight, axisPaint);

    // Grid lines and labels
    final textPainter = TextPainter(
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    );

    const ySteps = 4;
    for (var i = 0; i <= ySteps; i++) {
      final ratio = i / ySteps;
      final y = axisBottom.dy - (ratio * chartHeight);
      final weightValue = minWeight + (weightRange * ratio);
      canvas.drawLine(
        Offset(chartPadding.left, y),
        Offset(size.width - chartPadding.right, y),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: weightValue.toStringAsFixed(1),
        style: const TextStyle(fontSize: 11, color: Colors.black87),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chartPadding.left - 8 - textPainter.width, y - textPainter.height / 2),
      );
    }

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < sorted.length; i++) {
      final point = sorted[i];
      final dx = chartPadding.left + (chartWidth * point.date.difference(minDate).inDays / totalDays);
      final dy = axisBottom.dy - ((point.weight - minWeight) / weightRange * chartHeight);
      final currentOffset = Offset(dx, dy);

      if (i == 0) {
        path.moveTo(dx, dy);
        fillPath.moveTo(dx, axisBottom.dy);
        fillPath.lineTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
        fillPath.lineTo(dx, dy);
      }

      // Draw point marker.
      canvas.drawCircle(currentOffset, 4, Paint()..color = Colors.green.shade900);
    }

    if (sorted.isNotEmpty) {
      fillPath.lineTo(
        chartPadding.left + chartWidth * sorted.last.date.difference(minDate).inDays / totalDays,
        axisBottom.dy,
      );
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);
    }

    // X labels (start, middle, end)
    if (sorted.isNotEmpty) {
      final labelDates = <DateTime>{sorted.first.date};
      if (sorted.length > 2) {
        labelDates.add(sorted[sorted.length ~/ 2].date);
      }
      labelDates.add(sorted.last.date);

      for (final date in labelDates) {
        final dx = chartPadding.left + (chartWidth * date.difference(minDate).inDays / totalDays);
        final label = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
        textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(fontSize: 11, color: Colors.black87),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(dx - textPainter.width / 2, axisBottom.dy + 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
