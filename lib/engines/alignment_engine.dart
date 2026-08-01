import 'dart:math';
import '../models/analysis_models.dart';

/// Pairwise & simple multiple sequence alignment engine.
class AlignmentEngine {
  static const int matchScore = 2;
  static const int mismatchScore = -1;
  static const int gapPenalty = -2;

  static int _subScore(String a, String b) =>
      a == b ? matchScore : mismatchScore;

  /// Needleman-Wunsch global alignment.
  static PairwiseAlignmentResult globalAlign(String a, String b) {
    final n = a.length;
    final m = b.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (int i = 0; i <= n; i++) {
      dp[i][0] = i * gapPenalty;
    }
    for (int j = 0; j <= m; j++) {
      dp[0][j] = j * gapPenalty;
    }

    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        final diag = dp[i - 1][j - 1] + _subScore(a[i - 1], b[j - 1]);
        final up = dp[i - 1][j] + gapPenalty;
        final left = dp[i][j - 1] + gapPenalty;
        dp[i][j] = max(diag, max(up, left));
      }
    }

    final sbA = StringBuffer();
    final sbB = StringBuffer();
    int i = n, j = m;
    while (i > 0 || j > 0) {
      if (i > 0 &&
          j > 0 &&
          dp[i][j] == dp[i - 1][j - 1] + _subScore(a[i - 1], b[j - 1])) {
        sbA.write(a[i - 1]);
        sbB.write(b[j - 1]);
        i--;
        j--;
      } else if (i > 0 && dp[i][j] == dp[i - 1][j] + gapPenalty) {
        sbA.write(a[i - 1]);
        sbB.write('-');
        i--;
      } else {
        sbA.write('-');
        sbB.write(b[j - 1]);
        j--;
      }
    }

    final alignedA = sbA.toString().split('').reversed.join();
    final alignedB = sbB.toString().split('').reversed.join();
    return _buildResult(alignedA, alignedB, dp[n][m], AlignmentMode.global);
  }

  /// Smith-Waterman local alignment.
  static PairwiseAlignmentResult localAlign(String a, String b) {
    final n = a.length;
    final m = b.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    int maxScore = 0, maxI = 0, maxJ = 0;

    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        final diag = dp[i - 1][j - 1] + _subScore(a[i - 1], b[j - 1]);
        final up = dp[i - 1][j] + gapPenalty;
        final left = dp[i][j - 1] + gapPenalty;
        dp[i][j] = [0, diag, up, left].reduce(max);
        if (dp[i][j] > maxScore) {
          maxScore = dp[i][j];
          maxI = i;
          maxJ = j;
        }
      }
    }

    final sbA = StringBuffer();
    final sbB = StringBuffer();
    int i = maxI, j = maxJ;
    while (i > 0 && j > 0 && dp[i][j] != 0) {
      if (dp[i][j] == dp[i - 1][j - 1] + _subScore(a[i - 1], b[j - 1])) {
        sbA.write(a[i - 1]);
        sbB.write(b[j - 1]);
        i--;
        j--;
      } else if (dp[i][j] == dp[i - 1][j] + gapPenalty) {
        sbA.write(a[i - 1]);
        sbB.write('-');
        i--;
      } else {
        sbA.write('-');
        sbB.write(b[j - 1]);
        j--;
      }
    }

    final alignedA = sbA.toString().split('').reversed.join();
    final alignedB = sbB.toString().split('').reversed.join();
    return _buildResult(alignedA, alignedB, maxScore, AlignmentMode.local);
  }

  static PairwiseAlignmentResult _buildResult(
    String alignedA,
    String alignedB,
    int score,
    AlignmentMode mode,
  ) {
    int matches = 0, gaps = 0, similar = 0;
    final len = alignedA.length;
    for (int k = 0; k < len; k++) {
      if (alignedA[k] == '-' || alignedB[k] == '-') {
        gaps++;
      } else if (alignedA[k] == alignedB[k]) {
        matches++;
        similar++;
      } else {
        // simple similarity: purines/pyrimidines groups
        if (_isSimilar(alignedA[k], alignedB[k])) similar++;
      }
    }
    final identity = len == 0 ? 0.0 : matches / len * 100;
    final similarity = len == 0 ? 0.0 : similar / len * 100;
    return PairwiseAlignmentResult(
      alignedSeqA: alignedA,
      alignedSeqB: alignedB,
      score: score,
      identityPercent: identity,
      similarityPercent: similarity,
      gaps: gaps,
      mode: mode,
    );
  }

  static bool _isSimilar(String x, String y) {
    const purines = {'A', 'G'};
    const pyrimidines = {'C', 'T', 'U'};
    return (purines.contains(x) && purines.contains(y)) ||
        (pyrimidines.contains(x) && pyrimidines.contains(y));
  }

  /// Simple progressive multiple sequence alignment:
  /// Aligns sequences one by one against a growing consensus/profile using
  /// pairwise global alignment (center-star-like heuristic).
  static MultipleAlignmentResult multipleAlign(
    List<String> names,
    List<String> sequences,
  ) {
    if (sequences.isEmpty) {
      return MultipleAlignmentResult(
        names: [],
        alignedSequences: [],
        averageIdentity: 0,
        consensusLength: 0,
        consensusSequence: '',
      );
    }
    if (sequences.length == 1) {
      return MultipleAlignmentResult(
        names: names,
        alignedSequences: [sequences.first],
        averageIdentity: 100,
        consensusLength: sequences.first.length,
        consensusSequence: sequences.first,
      );
    }

    // Choose the longest sequence as the initial reference/center.
    int centerIdx = 0;
    for (int i = 1; i < sequences.length; i++) {
      if (sequences[i].length > sequences[centerIdx].length) centerIdx = i;
    }

    List<String> aligned = List.filled(sequences.length, '');
    aligned[centerIdx] = sequences[centerIdx];

    for (int i = 0; i < sequences.length; i++) {
      if (i == centerIdx) continue;
      final res = globalAlign(aligned[centerIdx], sequences[i]);
      aligned[centerIdx] = res.alignedSeqA;
      aligned[i] = res.alignedSeqB;
      // Re-pad all previously aligned sequences to the new reference length if it grew
      for (int k = 0; k < sequences.length; k++) {
        if (k != i && k != centerIdx && aligned[k].isNotEmpty) {
          if (aligned[k].length < aligned[centerIdx].length) {
            aligned[k] = aligned[k].padRight(aligned[centerIdx].length, '-');
          }
        }
      }
    }

    final maxLen = aligned.map((s) => s.length).reduce(max);
    aligned = aligned.map((s) => s.padRight(maxLen, '-')).toList();

    // Build consensus
    final sb = StringBuffer();
    for (int col = 0; col < maxLen; col++) {
      final Map<String, int> counts = {};
      for (final s in aligned) {
        if (col < s.length) {
          counts[s[col]] = (counts[s[col]] ?? 0) + 1;
        }
      }
      String best = '-';
      int bestCount = 0;
      counts.forEach((k, v) {
        if (v > bestCount) {
          best = k;
          bestCount = v;
        }
      });
      sb.write(best);
    }
    final consensus = sb.toString();

    // Average pairwise identity
    double totalIdentity = 0;
    int pairCount = 0;
    for (int i = 0; i < aligned.length; i++) {
      for (int j = i + 1; j < aligned.length; j++) {
        int matches = 0;
        int compared = 0;
        for (int k = 0; k < maxLen; k++) {
          final ci = i < aligned.length && k < aligned[i].length
              ? aligned[i][k]
              : '-';
          final cj = j < aligned.length && k < aligned[j].length
              ? aligned[j][k]
              : '-';
          if (ci != '-' || cj != '-') {
            compared++;
            if (ci == cj) matches++;
          }
        }
        if (compared > 0) {
          totalIdentity += matches / compared * 100;
          pairCount++;
        }
      }
    }
    final avgIdentity = pairCount == 0 ? 0.0 : totalIdentity / pairCount;

    return MultipleAlignmentResult(
      names: names,
      alignedSequences: aligned,
      averageIdentity: avgIdentity,
      consensusLength: maxLen,
      consensusSequence: consensus,
    );
  }
}
