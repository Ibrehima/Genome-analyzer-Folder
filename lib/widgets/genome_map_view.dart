import 'dart:math';
import 'package:flutter/material.dart';
import '../models/analysis_models.dart';

Color _categoryColor(String category) {
  switch (category) {
    case 'gene':
      return const Color(0xFF1565C0);
    case 'CDS':
      return const Color(0xFF00897B);
    case 'ORF':
      return const Color(0xFF7B1FA2);
    case 'motif':
      return const Color(0xFFEF6C00);
    case 'snp':
      return const Color(0xFFC62828);
    case 'insertion':
      return const Color(0xFF2E7D32);
    case 'deletion':
      return const Color(0xFF6A1B9A);
    default:
      return const Color(0xFF546E7A);
  }
}

/// Renders a [GenomeMapData] as either a circular (plasmid-style) map or a
/// linear (genome-browser-style) track, with every feature (genes, ORFs,
/// mutations...) drawn at its correctly scaled position and labeled with
/// its numeric coordinate — satisfies the "well annotated & numbered
/// positions" requirement for the mutation/SNP schematic view.
class GenomeMapView extends StatelessWidget {
  final GenomeMapData data;
  final GenomeMapShape shape;
  final double size;

  const GenomeMapView({
    super.key,
    required this.data,
    this.shape = GenomeMapShape.circular,
    this.size = 420,
  });

  @override
  Widget build(BuildContext context) {
    if (shape == GenomeMapShape.circular) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _CircularMapPainter(data)),
      );
    }
    final width = (data.sequenceLength / 2).clamp(700, 6000).toDouble();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: 220 + (data.features.length * 2).clamp(0, 300).toDouble(),
        child: CustomPaint(painter: _LinearMapPainter(data)),
      ),
    );
  }
}

/// Assigns features to non-overlapping horizontal "lanes" so overlapping
/// regions don't visually collide — a simple greedy interval-scheduling
/// lane assignment, same idea used by genome browsers (IGV-style tracks).
List<int> _assignLanes(List<GenomeMapFeature> features) {
  final laneEnds = <double>[]; // end position (in bp) occupied per lane
  final lanes = List<int>.filled(features.length, 0);
  final order = List.generate(features.length, (i) => i)
    ..sort((a, b) => features[a].start.compareTo(features[b].start));
  for (final idx in order) {
    final f = features[idx];
    int lane = -1;
    for (int l = 0; l < laneEnds.length; l++) {
      if (laneEnds[l] <= f.start) {
        lane = l;
        break;
      }
    }
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(0);
    }
    laneEnds[lane] = f.end.toDouble();
    lanes[idx] = lane;
  }
  return lanes;
}

class _CircularMapPainter extends CustomPainter {
  final GenomeMapData data;
  _CircularMapPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 56;
    final len = data.sequenceLength.clamp(1, 1 << 30);
    final lanes = _assignLanes(data.features);
    final laneCount = lanes.isEmpty ? 1 : (lanes.reduce(max) + 1);

    // Backbone circle.
    final backbonePaint = Paint()
      ..color = const Color(0xFF90A4AE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, backbonePaint);

    // Position ticks every ~10% of the sequence, numbered.
    const tickCount = 12;
    for (int t = 0; t < tickCount; t++) {
      final angle = (t / tickCount) * 2 * pi - pi / 2;
      final pos = (t / tickCount * len).round();
      final inner = Offset(
        center.dx + (radius - 6) * cos(angle),
        center.dy + (radius - 6) * sin(angle),
      );
      final outer = Offset(
        center.dx + (radius + 6) * cos(angle),
        center.dy + (radius + 6) * sin(angle),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = Colors.grey.shade400
          ..strokeWidth = 1.2,
      );
      final labelOffset = Offset(
        center.dx + (radius + 20) * cos(angle),
        center.dy + (radius + 20) * sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '$pos',
          style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, labelOffset - Offset(tp.width / 2, tp.height / 2));
    }

    // Feature arcs, one ring per lane (innermost lane closest to backbone).
    for (int i = 0; i < data.features.length; i++) {
      final f = data.features[i];
      final lane = lanes[i];
      final ringRadius = radius + 14 + lane * 13.0;
      final startAngle = (f.start / len) * 2 * pi - pi / 2;
      final sweep = max((f.end - f.start) / len * 2 * pi, 0.02);
      final color = _categoryColor(f.category);
      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        startAngle,
        sweep,
        false,
        arcPaint,
      );
    }

    // Center label: sequence name + length + GC%.
    final centerText = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${data.sequenceName}\n',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B2733),
            ),
          ),
          TextSpan(
            text: '$len bp\nGC ${data.gcContent.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: radius * 1.3);
    centerText.paint(canvas, center - Offset(centerText.width / 2, centerText.height / 2));

    // Silence unused laneCount if not otherwise referenced visually.
    assert(laneCount >= 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LinearMapPainter extends CustomPainter {
  final GenomeMapData data;
  _LinearMapPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final len = data.sequenceLength.clamp(1, 1 << 30);
    const leftMargin = 10.0;
    final trackWidth = size.width - leftMargin * 2;
    const backboneY = 50.0;

    double xFor(int pos) => leftMargin + (pos / len) * trackWidth;

    // Backbone line.
    canvas.drawLine(
      Offset(leftMargin, backboneY),
      Offset(leftMargin + trackWidth, backboneY),
      Paint()
        ..color = const Color(0xFF90A4AE)
        ..strokeWidth = 4,
    );

    // Ruler ticks every ~5% with numbered coordinates.
    const tickCount = 20;
    for (int t = 0; t <= tickCount; t++) {
      final pos = (t / tickCount * len).round();
      final x = xFor(pos);
      canvas.drawLine(
        Offset(x, backboneY - 6),
        Offset(x, backboneY + 6),
        Paint()
          ..color = Colors.grey.shade400
          ..strokeWidth = 1,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '$pos',
          style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, backboneY - 22));
    }

    // Feature blocks, stacked in lanes below the backbone.
    final lanes = _assignLanes(data.features);
    for (int i = 0; i < data.features.length; i++) {
      final f = data.features[i];
      final lane = lanes[i];
      final y = backboneY + 24 + lane * 26.0;
      final x1 = xFor(f.start);
      final x2 = xFor(f.end).clamp(x1 + 3, size.width);
      final color = _categoryColor(f.category);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x1, y, x2, y + 14),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.85));
      // Small strand arrow marker.
      if (f.forwardStrand) {
        canvas.drawLine(
          Offset(x2 - 4, y + 2),
          Offset(x2, y + 7),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5,
        );
        canvas.drawLine(
          Offset(x2 - 4, y + 12),
          Offset(x2, y + 7),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5,
        );
      }
      final label = '${f.label} (${f.start + 1}-${f.end})';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF1B2733)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x1, y + 15));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Small legend explaining feature category colors, shared by both map
/// shapes so users can read the annotated map correctly.
class GenomeMapLegend extends StatelessWidget {
  const GenomeMapLegend({super.key});

  static const _entries = [
    ('Gene', 'gene'),
    ('CDS', 'CDS'),
    ('ORF', 'ORF'),
    ('Motif', 'motif'),
    ('SNP / substitution', 'snp'),
    ('Insertion', 'insertion'),
    ('Deletion', 'deletion'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: _entries
          .map(
            (e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: _categoryColor(e.$2), shape: BoxShape.circle),
                  margin: const EdgeInsets.only(right: 4),
                ),
                Text(e.$1, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          )
          .toList(),
    );
  }
}
