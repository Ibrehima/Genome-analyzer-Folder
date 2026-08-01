import 'dart:math';
import 'package:flutter/material.dart';
import '../models/analysis_models.dart';

/// Interactive (drag-to-rotate) renderer for idealized/schematic 3D
/// molecular structures (DNA double helix or protein backbone ribbon).
/// Uses a simple manual rotation + perspective projection — not a full
/// 3D graphics engine, but sufficient for visual/educational intuition.
class Structure3DView extends StatefulWidget {
  final Structure3DResult structure;
  final double height;
  const Structure3DView({
    super.key,
    required this.structure,
    this.height = 340,
  });

  @override
  State<Structure3DView> createState() => _Structure3DViewState();
}

class _Structure3DViewState extends State<Structure3DView> {
  double _rotY = 0.4;
  double _rotX = 0.2;
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _rotY += details.delta.dx * 0.01;
          _rotX += details.delta.dy * 0.01;
        });
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_scale * details.scale).clamp(0.4, 3.0);
        });
      },
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFF0B1626),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter: _Structure3DPainter(
              structure: widget.structure,
              rotX: _rotX,
              rotY: _rotY,
              scale: _scale,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _Structure3DPainter extends CustomPainter {
  final Structure3DResult structure;
  final double rotX;
  final double rotY;
  final double scale;

  _Structure3DPainter({
    required this.structure,
    required this.rotX,
    required this.rotY,
    required this.scale,
  });

  Color _colorFor(String kind) {
    switch (kind) {
      case 'helix':
        return const Color(0xFF4FC3F7);
      case 'sheet':
        return const Color(0xFFFFB74D);
      case 'coil':
        return const Color(0xFF81C784);
      case 'basepair':
        return const Color(0xFFB39DDB);
      default:
        return const Color(0xFFE0E0E0);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final atoms = structure.atoms;
    if (atoms.isEmpty) return;

    double cx = 0, cy = 0, cz = 0;
    for (final a in atoms) {
      cx += a.x;
      cy += a.y;
      cz += a.z;
    }
    cx /= atoms.length;
    cy /= atoms.length;
    cz /= atoms.length;

    final projected = <Offset>[];
    final depths = <double>[];
    final baseScale = (size.shortestSide / 30).clamp(4.0, 30.0) * scale;

    final cosY = cos(rotY), sinY = sin(rotY);
    final cosX = cos(rotX), sinX = sin(rotX);

    for (final a in atoms) {
      final x = a.x - cx;
      final y = a.y - cy;
      final z = a.z - cz;
      final x1 = x * cosY + z * sinY;
      final z1 = -x * sinY + z * cosY;
      final y2 = y * cosX - z1 * sinX;
      final z2 = y * sinX + z1 * cosX;
      final perspective = 260 / (260 + z2);
      final px = size.width / 2 + x1 * baseScale * perspective;
      final py = size.height / 2 + y2 * baseScale * perspective;
      projected.add(Offset(px, py));
      depths.add(z2);
    }

    // Draw bonds first (behind atoms)
    for (final bond in structure.bonds) {
      final i = bond[0], j = bond[1];
      if (i >= projected.length || j >= projected.length) continue;
      final avgDepth = (depths[i] + depths[j]) / 2;
      final alpha = (1 - (avgDepth.abs() / 400)).clamp(0.25, 1.0);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.55)
        ..strokeWidth = 1.6;
      canvas.drawLine(projected[i], projected[j], paint);
    }

    // Draw atoms, back-to-front for a simple depth sort
    final order = List<int>.generate(atoms.length, (i) => i)
      ..sort((a, b) => depths[a].compareTo(depths[b]));
    for (final idx in order) {
      final atom = atoms[idx];
      final depth = depths[idx];
      final alpha = (1 - (depth.abs() / 500)).clamp(0.35, 1.0);
      final radius = (3.5 * (1 - depth / 600)).clamp(1.5, 6.0);
      final paint = Paint()
        ..color = _colorFor(atom.kind).withValues(alpha: alpha);
      canvas.drawCircle(projected[idx], radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Structure3DPainter oldDelegate) {
    return oldDelegate.rotX != rotX ||
        oldDelegate.rotY != rotY ||
        oldDelegate.scale != scale ||
        oldDelegate.structure != structure;
  }
}
