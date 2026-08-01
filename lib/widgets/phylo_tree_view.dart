import 'package:flutter/material.dart';
import '../models/analysis_models.dart';
import '../engines/phylo_engine.dart';

/// Renders a phylogenetic tree (cladogram-style) using CustomPaint.
class PhyloTreeView extends StatelessWidget {
  final PhyloTreeResult tree;
  final double height;

  const PhyloTreeView({super.key, required this.tree, this.height = 420});

  @override
  Widget build(BuildContext context) {
    final leafCount = tree.leafNames.length;
    final width = 500.0;
    final computedHeight = (leafCount * 34.0).clamp(height, 4000.0);
    PhyloEngine.layoutTree(
      tree.root,
      width: width - 160,
      height: computedHeight - 20,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: SizedBox(
          width: width + 20,
          height: computedHeight,
          child: CustomPaint(painter: _TreePainter(tree.root)),
        ),
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  final PhyloNode root;
  _TreePainter(this.root);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF7B1FA2)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = const Color(0xFF7B1FA2);

    void drawNode(PhyloNode node, double parentX, double parentY) {
      // Horizontal branch from parent depth to this node's depth (at same y)
      canvas.drawLine(
        Offset(parentX, node.y),
        Offset(node.x, node.y),
        linePaint,
      );
      // Vertical connector at parentX between children when applicable handled by caller
      if (node.isLeaf) {
        canvas.drawCircle(Offset(node.x, node.y), 3, dotPaint);
        final tp = TextPainter(
          text: TextSpan(
            text: '  ${node.label}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1B2733),
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(node.x + 4, node.y - tp.height / 2));
      } else {
        // vertical line spanning children's y at this node's x
        final ys = node.children.map((c) => c.y).toList();
        final minY = ys.reduce((a, b) => a < b ? a : b);
        final maxY = ys.reduce((a, b) => a > b ? a : b);
        canvas.drawLine(Offset(node.x, minY), Offset(node.x, maxY), linePaint);
        for (final c in node.children) {
          drawNode(c, node.x, c.y);
        }
      }
    }

    // Root: draw from x=0
    if (root.isLeaf) {
      drawNode(root, 0, root.y);
    } else {
      final ys = root.children.map((c) => c.y).toList();
      final minY = ys.reduce((a, b) => a < b ? a : b);
      final maxY = ys.reduce((a, b) => a > b ? a : b);
      canvas.drawLine(Offset(root.x, minY), Offset(root.x, maxY), linePaint);
      for (final c in root.children) {
        drawNode(c, root.x, c.y);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
