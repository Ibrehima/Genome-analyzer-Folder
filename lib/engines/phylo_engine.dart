import 'dart:math';
import '../models/analysis_models.dart';

/// Phylogenetic tree construction using distance-matrix based methods.
class PhyloEngine {
  /// Computes a simple p-distance matrix (proportion of differing sites)
  /// between aligned sequences. If sequences are not aligned/equal length,
  /// falls back to k-mer based distance.
  static List<List<double>> distanceMatrix(List<String> sequences) {
    final n = sequences.length;
    final matrix = List.generate(n, (_) => List<double>.filled(n, 0));
    final sameLength = sequences.map((s) => s.length).toSet().length == 1;

    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        double dist;
        if (sameLength) {
          dist = _pDistance(sequences[i], sequences[j]);
        } else {
          dist = _kmerDistance(sequences[i], sequences[j]);
        }
        matrix[i][j] = dist;
        matrix[j][i] = dist;
      }
    }
    return matrix;
  }

  static double _pDistance(String a, String b) {
    int diff = 0;
    int compared = 0;
    for (int k = 0; k < a.length && k < b.length; k++) {
      if (a[k] == '-' && b[k] == '-') continue;
      compared++;
      if (a[k] != b[k]) diff++;
    }
    return compared == 0 ? 0 : diff / compared;
  }

  static double _kmerDistance(String a, String b, {int k = 6}) {
    Set<String> kmers(String s) {
      final set = <String>{};
      for (int i = 0; i + k <= s.length; i++) {
        set.add(s.substring(i, i + k));
      }
      return set;
    }

    final setA = kmers(a);
    final setB = kmers(b);
    if (setA.isEmpty || setB.isEmpty) return 1.0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 1.0 : 1.0 - intersection / union;
  }

  /// UPGMA hierarchical clustering tree construction.
  static PhyloTreeResult buildUPGMA(
    List<String> names,
    List<String> sequences,
  ) {
    final n = names.length;
    final dist = distanceMatrix(sequences);

    List<PhyloNode> clusters = List.generate(
      n,
      (i) => PhyloNode(label: names[i]),
    );
    List<int> sizes = List.filled(n, 1);
    List<List<double>> d = dist.map((row) => List<double>.from(row)).toList();
    List<double> heights = List.filled(n, 0);

    List<PhyloNode> currentNodes = List.from(clusters);
    List<int> currentSizes = List.from(sizes);
    List<double> currentHeights = List.from(heights);
    List<List<double>> currentDist = d;
    List<int> activeIndices = List.generate(n, (i) => i);

    while (activeIndices.length > 1) {
      double minDist = double.infinity;
      int mi = -1, mj = -1;
      for (int a = 0; a < activeIndices.length; a++) {
        for (int b = a + 1; b < activeIndices.length; b++) {
          final i = activeIndices[a];
          final j = activeIndices[b];
          if (currentDist[i][j] < minDist) {
            minDist = currentDist[i][j];
            mi = i;
            mj = j;
          }
        }
      }
      if (mi == -1) break;

      final newHeight = minDist / 2;
      final nodeI = currentNodes[mi];
      final nodeJ = currentNodes[mj];
      final branchI = max(0.0, newHeight - currentHeights[mi]);
      final branchJ = max(0.0, newHeight - currentHeights[mj]);

      final merged = PhyloNode(
        children: [
          PhyloNode(
            label: nodeI.label,
            branchLength: branchI,
            children: nodeI.children,
          ),
          PhyloNode(
            label: nodeJ.label,
            branchLength: branchJ,
            children: nodeJ.children,
          ),
        ],
      );

      final newSize = currentSizes[mi] + currentSizes[mj];

      // Compute new distances to all other active clusters (weighted average)
      final Map<int, double> newDistances = {};
      for (final idx in activeIndices) {
        if (idx == mi || idx == mj) continue;
        final combined =
            (currentDist[mi][idx] * currentSizes[mi] +
                currentDist[mj][idx] * currentSizes[mj]) /
            newSize;
        newDistances[idx] = combined;
      }

      // Remove mi, mj from active; add new merged as mi's slot re-purposed
      activeIndices.remove(mi);
      activeIndices.remove(mj);

      final newIndex = currentNodes.length;
      currentNodes.add(merged);
      currentSizes.add(newSize);
      currentHeights.add(newHeight);

      // Expand distance matrix
      for (final row in currentDist) {
        row.add(0);
      }
      currentDist.add(List<double>.filled(currentDist[0].length, 0));
      newDistances.forEach((idx, val) {
        currentDist[newIndex][idx] = val;
        currentDist[idx][newIndex] = val;
      });

      activeIndices.add(newIndex);
    }

    final rootIndex = activeIndices.first;
    final root = currentNodes[rootIndex];
    return PhyloTreeResult(root: root, method: 'UPGMA', leafNames: names);
  }

  /// Neighbor-Joining tree construction (simplified).
  static PhyloTreeResult buildNeighborJoining(
    List<String> names,
    List<String> sequences,
  ) {
    final n = names.length;
    if (n < 3) {
      return buildUPGMA(names, sequences);
    }
    final dist = distanceMatrix(sequences);
    List<List<double>> d = dist.map((row) => List<double>.from(row)).toList();
    List<PhyloNode> nodes = List.generate(n, (i) => PhyloNode(label: names[i]));
    List<int> activeIndices = List.generate(n, (i) => i);

    while (activeIndices.length > 2) {
      final m = activeIndices.length;
      final List<double> r = List.filled(m, 0);
      for (int a = 0; a < m; a++) {
        double sum = 0;
        for (int b = 0; b < m; b++) {
          if (a == b) continue;
          sum += d[activeIndices[a]][activeIndices[b]];
        }
        r[a] = sum;
      }

      double minQ = double.infinity;
      int mi = -1, mj = -1;
      for (int a = 0; a < m; a++) {
        for (int b = a + 1; b < m; b++) {
          final i = activeIndices[a];
          final j = activeIndices[b];
          final q = (m - 2) * d[i][j] - r[a] - r[b];
          if (q < minQ) {
            minQ = q;
            mi = a;
            mj = b;
          }
        }
      }
      if (mi == -1) break;

      final i = activeIndices[mi];
      final j = activeIndices[mj];
      final dij = d[i][j];
      final branchI = max(
        0.0,
        0.5 * dij + (m > 2 ? (r[mi] - r[mj]) / (2 * (m - 2)) : 0),
      );
      final branchJ = max(0.0, dij - branchI);

      final merged = PhyloNode(
        children: [
          PhyloNode(
            label: nodes[i].label,
            branchLength: branchI,
            children: nodes[i].children,
          ),
          PhyloNode(
            label: nodes[j].label,
            branchLength: branchJ,
            children: nodes[j].children,
          ),
        ],
      );

      final newIndex = nodes.length;
      nodes.add(merged);

      for (final row in d) {
        row.add(0);
      }
      d.add(List<double>.filled(d[0].length, 0));

      for (final k in activeIndices) {
        if (k == i || k == j) continue;
        final newDist = 0.5 * (d[i][k] + d[j][k] - dij);
        d[newIndex][k] = max(0.0, newDist);
        d[k][newIndex] = max(0.0, newDist);
      }

      activeIndices.removeAt(mj);
      activeIndices.removeAt(mi);
      activeIndices.add(newIndex);
    }

    // Join final two nodes
    final i = activeIndices[0];
    final j = activeIndices[1];
    final finalDist = d[i][j];
    final root = PhyloNode(
      children: [
        PhyloNode(
          label: nodes[i].label,
          branchLength: finalDist / 2,
          children: nodes[i].children,
        ),
        PhyloNode(
          label: nodes[j].label,
          branchLength: finalDist / 2,
          children: nodes[j].children,
        ),
      ],
    );

    return PhyloTreeResult(
      root: root,
      method: 'Neighbor-Joining',
      leafNames: names,
    );
  }

  /// Assigns x/y layout coordinates to tree nodes for rendering (cladogram-style).
  static void layoutTree(
    PhyloNode root, {
    double width = 800,
    double height = 600,
  }) {
    final leaves = <PhyloNode>[];
    void collectLeaves(PhyloNode node) {
      if (node.isLeaf) {
        leaves.add(node);
      } else {
        for (final c in node.children) {
          collectLeaves(c);
        }
      }
    }

    collectLeaves(root);

    final leafSpacing = leaves.isEmpty ? height : height / leaves.length;
    for (int i = 0; i < leaves.length; i++) {
      leaves[i].y = leafSpacing * (i + 0.5);
    }

    double maxDepth = 0;
    void computeDepth(PhyloNode node, double depth) {
      final newDepth = depth + node.branchLength;
      if (newDepth > maxDepth) maxDepth = newDepth;
      for (final c in node.children) {
        computeDepth(c, newDepth);
      }
    }

    computeDepth(root, 0);
    if (maxDepth == 0) maxDepth = 1;

    double assignX(PhyloNode node, double depth) {
      final newDepth = depth + node.branchLength;
      node.x = (newDepth / maxDepth) * width;
      if (node.isLeaf) {
        return node.y;
      }
      double sumY = 0;
      for (final c in node.children) {
        sumY += assignX(c, newDepth);
      }
      node.y = sumY / node.children.length;
      return node.y;
    }

    assignX(root, 0);
  }
}
