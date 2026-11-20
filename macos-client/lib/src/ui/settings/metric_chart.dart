import 'dart:math' as math;

import 'package:flutter/material.dart';

class MetricChart extends StatelessWidget {
  const MetricChart({
    super.key,
    required this.title,
    required this.values,
    required this.color,
    this.bars = false,
    this.fixedMax,
  });

  final String title;
  final List<double> values;
  final Color color;
  final bool bars;
  final double? fixedMax;

  double get _max {
    if (values.isEmpty) return 1;
    final m = values.reduce(math.max);
    return fixedMax ?? (m <= 0 ? 1 : m);
  }

  double get _avg =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Text(
              '평균 ${_avg.toStringAsFixed(values.isEmpty || _avg >= 100 ? 0 : 1)}'
              ' · 최대 ${_max.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 76,
          child: values.isEmpty
              ? const Center(
                  child: Text('데이터 없음',
                      style: TextStyle(fontSize: 11, color: Colors.grey)))
              : CustomPaint(
                  painter: _MetricChartPainter(
                    values: values,
                    maxValue: _max,
                    color: color,
                    bars: bars,
                  ),
                  size: Size.infinite,
                ),
        ),
      ],
    );
  }
}

class _MetricChartPainter extends CustomPainter {
  _MetricChartPainter({
    required this.values,
    required this.maxValue,
    required this.color,
    required this.bars,
  });

  final List<double> values;
  final double maxValue;
  final Color color;
  final bool bars;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.grey.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final step = values.length > 1 ? size.width / (values.length - 1) : 0.0;
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : i * step;
      final ratio = (values[i] / maxValue).clamp(0.0, 1.0);
      points.add(Offset(x, size.height - ratio * size.height));
    }

    if (bars) {
      final barWidth = values.length == 1
          ? 12.0
          : math.max(2.0, step * 0.55);
      final paint = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;
      for (final p in points) {
        canvas.drawRect(
          Rect.fromLTWH(p.dx - barWidth / 2, p.dy, barWidth, size.height - p.dy),
          paint,
        );
      }
      return;
    }

    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      if (i == 0) {
        path.moveTo(points[i].dx, points[i].dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = color;
    for (final p in points) {
      canvas.drawCircle(p, 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _MetricChartPainter old) =>
      old.values != values || old.maxValue != maxValue || old.color != color;
}
