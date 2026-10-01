import 'dart:math';
import 'dart:typed_data';
import '../models/analysis_models.dart';
import 'substitution_matrices.dart';

/// Pairwise & multiple sequence alignment engine.
///
/// Supports:
///  - 3 alignment strategies: global (Needleman-Wunsch), local
///    (Smith-Waterman) and semi-global / "glocal" (fit one sequence inside
///    the other without end-gap penalties).
///  - 2 gap-penalty models: linear (one cost per gap base) and affine
///    (separate open/extend costs, via the Gotoh 3-matrix recurrence).
///  - 4 substitution schemes: simple match/mismatch, DNA
///    transition/transversion-aware, BLOSUM62 and PAM250 (protein).
///  - Automatic banded DP for long, near-equal-length sequence pairs, which
///    turns the O(n*m) scan into an O(n*k) scan (k = band width) when the
///    full table isn't needed — a big win for e.g. two ~5kb amplicons that
///    are expected to be highly similar.
///  - Flat `Int32List` DP matrices (instead of `List<List<int>>`) for lower
///    memory overhead and faster inner-loop access.
///  - A proper multiple sequence alignment with two selectable methods:
///    the original fast "center sequence" heuristic, and a more accurate
///    progressive alignment driven by a UPGMA guide tree built from k-mer
///    distances (merges the most similar pair/profile first, ClustalW-style).
class AlignmentEngine {
  // Backwards-compatible default scoring constants (simple scheme).
  static const int matchScore = 2;
  static const int mismatchScore = -1;
  static const int gapPenalty = -2;

  static const int _negInf = -1 << 30;

  // ---------------------------------------------------------------------
  // Scoring helpers
  // ---------------------------------------------------------------------

  static int Function(String, String) _scorer(AlignmentOptions opt) {
    switch (opt.matrixType) {
      case SubstitutionMatrixType.simple:
        return (a, b) => a == b ? opt.matchScore : opt.mismatchScore;
      case SubstitutionMatrixType.dnaTransitionTransversion:
        return (a, b) => SubstitutionMatrices.dnaTransitionTransversion(
          a,
          b,
          matchScore: opt.matchScore,
          mismatchScore: opt.mismatchScore,
          transitionPenalty: opt.transitionPenalty,
        );
      case SubstitutionMatrixType.blosum62:
        return SubstitutionMatrices.blosum62;
      case SubstitutionMatrixType.pam250:
        return SubstitutionMatrices.pam250;
    }
  }

  /// Whether banding is safe/useful: both sequences reasonably long and of
  /// similar length (banding a global alignment of very different-length
  /// sequences would clip the true optimal path).
  static bool _shouldBand(int n, int m, AlignmentOptions opt) {
    if (!opt.autoBand) return false;
    if (n < opt.bandLengthThreshold && m < opt.bandLengthThreshold) {
      return false;
    }
    final diff = (n - m).abs();
    return diff <= opt.bandWidth;
  }

  // ---------------------------------------------------------------------
  // Public API (legacy signatures preserved, options parameter optional)
  // ---------------------------------------------------------------------

  /// Needleman-Wunsch global alignment (linear or affine gaps, any
  /// substitution scheme, optional banding for long similar sequences).
  static PairwiseAlignmentResult globalAlign(
    String a,
    String b, {
    AlignmentOptions options = const AlignmentOptions(),
  }) {
    final sw = Stopwatch()..start();
    final n = a.length;
    final m = b.length;
    final score = _scorer(options);
    final banded = _shouldBand(n, m, options);
    final band = banded ? max(options.bandWidth, (n - m).abs() + 4) : -1;

    final result = options.gapModel == GapModel.affine
        ? _affineGlobal(a, b, score, options, band)
        : _linearGlobal(a, b, score, options, band);

    sw.stop();
    return _finishResult(
      result.$1,
      result.$2,
      result.$3,
      AlignmentMode.global,
      options,
      banded,
      sw.elapsedMicroseconds,
    );
  }

  /// Smith-Waterman local alignment.
  static PairwiseAlignmentResult localAlign(
    String a,
    String b, {
    AlignmentOptions options = const AlignmentOptions(),
  }) {
    final sw = Stopwatch()..start();
    final score = _scorer(options);
    final result = options.gapModel == GapModel.affine
        ? _affineLocal(a, b, score, options)
        : _linearLocal(a, b, score, options);
    sw.stop();
    return _finishResult(
      result.$1,
      result.$2,
      result.$3,
      AlignmentMode.local,
      options,
      false,
      sw.elapsedMicroseconds,
    );
  }

  /// Semi-global ("glocal" / fit) alignment: sequence `b` is fit fully
  /// inside sequence `a` with no penalty for `a`'s overhanging ends. Ideal
  /// for primer-vs-template, read-vs-reference, or domain-vs-full-protein
  /// comparisons where one sequence is expected to sit fully inside the
  /// other. Identity/similarity are computed over the matched core only —
  /// the free, unaligned flanks of `a` are informational context, not part
  /// of the match.
  static PairwiseAlignmentResult glocalAlign(
    String a,
    String b, {
    AlignmentOptions options = const AlignmentOptions(),
  }) {
    final sw = Stopwatch()..start();
    final score = _scorer(options);
    final result = _semiGlobal(a, b, score, options);
    sw.stop();
    return _finishResult(
      result.$1,
      result.$2,
      result.$3,
      AlignmentMode.glocal,
      options,
      false,
      sw.elapsedMicroseconds,
      statsRange: result.$4,
    );
  }

  /// Convenience dispatcher used by the UI's mode selector.
  static PairwiseAlignmentResult align(
    String a,
    String b,
    AlignmentMode mode, {
    AlignmentOptions options = const AlignmentOptions(),
  }) {
    switch (mode) {
      case AlignmentMode.global:
        return globalAlign(a, b, options: options);
      case AlignmentMode.local:
        return localAlign(a, b, options: options);
      case AlignmentMode.glocal:
        return glocalAlign(a, b, options: options);
    }
  }

  // ---------------------------------------------------------------------
  // Linear-gap global alignment (flat Int32List DP, optional banding)
  // ---------------------------------------------------------------------

  static (String, String, int) _linearGlobal(
    String a,
    String b,
    int Function(String, String) score,
    AlignmentOptions opt,
    int band,
  ) {
    final n = a.length;
    final m = b.length;
    final gp = opt.gapPenalty;
    final banded = band > 0;
    final width = m + 1;
    final dp = Int32List((n + 1) * width);
    if (banded) {
      dp.fillRange(0, dp.length, _negInf);
    }

    int at(int i, int j) => dp[i * width + j];
    void set(int i, int j, int v) => dp[i * width + j] = v;

    int lo(int i) => banded ? max(0, i - band) : 0;
    int hi(int i) => banded ? min(m, i + band) : m;

    set(0, 0, 0);
    for (int j = lo(0) == 0 ? 1 : lo(0); j <= hi(0); j++) {
      set(0, j, j * gp);
    }
    for (int i = 1; i <= n; i++) {
      if (lo(i) == 0) set(i, 0, i * gp);
    }

    for (int i = 1; i <= n; i++) {
      final l = max(1, lo(i));
      final h = hi(i);
      final ai = a[i - 1];
      for (int j = l; j <= h; j++) {
        final diag = at(i - 1, j - 1) + score(ai, b[j - 1]);
        final up = j <= hi(i - 1) ? at(i - 1, j) + gp : _negInf;
        final left = j - 1 >= lo(i) ? at(i, j - 1) + gp : _negInf;
        set(i, j, max(diag, max(up, left)));
      }
    }

    final sbA = StringBuffer();
    final sbB = StringBuffer();
    int i = n, j = m;
    while (i > 0 || j > 0) {
      final cur = at(i, j);
      if (i > 0 &&
          j > 0 &&
          cur == at(i - 1, j - 1) + score(a[i - 1], b[j - 1])) {
        sbA.write(a[i - 1]);
        sbB.write(b[j - 1]);
        i--;
        j--;
      } else if (i > 0 && j <= hi(i - 1) && cur == at(i - 1, j) + gp) {
        sbA.write(a[i - 1]);
        sbB.write('-');
        i--;
      } else {
        sbA.write('-');
        sbB.write(b[j - 1]);
        j--;
      }
    }

    final alignedA = _reverse(sbA.toString());
    final alignedB = _reverse(sbB.toString());
    return (alignedA, alignedB, at(n, m));
  }

  // ---------------------------------------------------------------------
  // Affine-gap global alignment (Gotoh algorithm, 3 DP matrices)
  // ---------------------------------------------------------------------

  static (String, String, int) _affineGlobal(
    String a,
    String b,
    int Function(String, String) score,
    AlignmentOptions opt,
    int band,
  ) {
    final n = a.length;
    final m = b.length;
    final open = opt.gapOpenPenalty;
    final ext = opt.gapExtendPenalty;
    final width = m + 1;

    // M = best ending in a match/mismatch, X = best ending in gap in A
    // (i.e. consuming b, "insertion"), Y = best ending in gap in B.
    final M = Int32List((n + 1) * width)
      ..fillRange(0, (n + 1) * width, _negInf);
    final X = Int32List((n + 1) * width)
      ..fillRange(0, (n + 1) * width, _negInf);
    final Y = Int32List((n + 1) * width)
      ..fillRange(0, (n + 1) * width, _negInf);

    int idx(int i, int j) => i * width + j;

    M[idx(0, 0)] = 0;
    for (int j = 1; j <= m; j++) {
      Y[idx(0, j)] = open + ext * (j - 1);
      M[idx(0, j)] = _negInf;
    }
    for (int i = 1; i <= n; i++) {
      X[idx(i, 0)] = open + ext * (i - 1);
      M[idx(i, 0)] = _negInf;
    }

    for (int i = 1; i <= n; i++) {
      final ai = a[i - 1];
      for (int j = 1; j <= m; j++) {
        final sub = score(ai, b[j - 1]);
        final kDiag = idx(i - 1, j - 1);
        M[idx(i, j)] = max(M[kDiag], max(X[kDiag], Y[kDiag])) + sub;

        final kUp = idx(i - 1, j);
        X[idx(i, j)] = max(M[kUp] + open, X[kUp] + ext);

        final kLeft = idx(i, j - 1);
        Y[idx(i, j)] = max(M[kLeft] + open, Y[kLeft] + ext);
      }
    }

    final end = idx(n, m);
    final best = max(M[end], max(X[end], Y[end]));

    final sbA = StringBuffer();
    final sbB = StringBuffer();
    int i = n, j = m;
    // Track which matrix we're currently in during traceback.
    int state = M[end] >= X[end] && M[end] >= Y[end]
        ? 0
        : (X[end] >= Y[end] ? 1 : 2);

    while (i > 0 || j > 0) {
      if (state == 0 && i > 0 && j > 0) {
        sbA.write(a[i - 1]);
        sbB.write(b[j - 1]);
        final kDiag = idx(i - 1, j - 1);
        final sub = score(a[i - 1], b[j - 1]);
        final cur = M[idx(i, j)];
        if (cur == M[kDiag] + sub) {
          state = 0;
        } else if (cur == X[kDiag] + sub) {
          state = 1;
        } else {
          state = 2;
        }
        i--;
        j--;
      } else if (state == 1 && i > 0) {
        sbA.write(a[i - 1]);
        sbB.write('-');
        final kUp = idx(i - 1, j);
        final cur = X[idx(i, j)];
        state = (cur == M[kUp] + open) ? 0 : 1;
        i--;
      } else if (state == 2 && j > 0) {
        sbA.write('-');
        sbB.write(b[j - 1]);
        final kLeft = idx(i, j - 1);
        final cur = Y[idx(i, j)];
        state = (cur == M[kLeft] + open) ? 0 : 2;
        j--;
      } else if (i > 0) {
        sbA.write(a[i - 1]);
        sbB.write('-');
        i--;
      } else {
        sbA.write('-');
        sbB.write(b[j - 1]);
        j--;
      }
    }

    return (_reverse(sbA.toString()), _reverse(sbB.toString()), best);
  }

  // ---------------------------------------------------------------------
  // Linear-gap local alignment (Smith-Waterman)
  // ---------------------------------------------------------------------

  static (String, String, int) _linearLocal(
    String a,
    String b,
    int Function(String, String) score,
    AlignmentOptions opt,
  ) {
    final n = a.length;
    final m = b.length;
    final gp = opt.gapPenalty;
    final width = m + 1;
    final dp = Int32List((n + 1) * width);
    int idx(int i, int j) => i * width + j;

    int maxScore = 0, maxI = 0, maxJ = 0;
    for (int i = 1; i <= n; i++) {
      final ai = a[i - 1];
      for (int j = 1; j <= m; j++) {
        final diag = dp[idx(i - 1, j - 1)] + score(ai, b[j - 1]);
        final up = dp[idx(i - 1, j)] + gp;
        final left = dp[idx(i, j - 1)] + gp;
        int v = 0;
        if (diag > v) v = diag;
        if (up > v) v = up;
        if (left > v) v = left;
        dp[idx(i, j)] = v;
        if (v > maxScore) {
          maxScore = v;
          maxI = i;
          maxJ = j;
        }
      }
    }

    final sbA = StringBuffer();
    final sbB = StringBuffer();
    int i = maxI, j = maxJ;
    while (i > 0 && j > 0 && dp[idx(i, j)] != 0) {
      final cur = dp[idx(i, j)];
      if (cur == dp[idx(i - 1, j - 1)] + score(a[i - 1], b[j - 1])) {
        sbA.write(a[i - 1]);
        sbB.write(b[j - 1]);
        i--;
        j--;
      } else if (cur == dp[idx(i - 1, j)] + gp) {
        sbA.write(a[i - 1]);
        sbB.write('-');
        i--;
      } else {
        sbA.write('-');
        sbB.write(b[j - 1]);
        j--;
      }
    }

    return (_reverse(sbA.toString()), _reverse(sbB.toString()), maxScore);
  }

  // ---------------------------------------------------------------------
  // Affine-gap local alignment (Gotoh, local variant)
  // ---------------------------------------------------------------------

  static (String, String, int) _affineLocal(
    String a,
    String b,
    int Function(String, String) score,
    AlignmentOptions opt,
  ) {
    final n = a.length;
    final m = b.length;
    final open = opt.gapOpenPenalty;
    final ext = opt.gapExtendPenalty;
    final width = m + 1;
    final M = Int32List((n + 1) * width);
    final X = Int32List((n + 1) * width)
      ..fillRange(0, (n + 1) * width, _negInf);
    final Y = Int32List((n + 1) * width)
      ..fillRange(0, (n + 1) * width, _negInf);
    int idx(int i, int j) => i * width + j;

    int maxScore = 0, maxI = 0, maxJ = 0;
    for (int i = 1; i <= n; i++) {
      final ai = a[i - 1];
      for (int j = 1; j <= m; j++) {
        final kDiag = idx(i - 1, j - 1);
        final sub = score(ai, b[j - 1]);
        final mVal = max(0, max(M[kDiag], max(X[kDiag], Y[kDiag])) + sub);
        M[idx(i, j)] = mVal;

        final kUp = idx(i - 1, j);
        X[idx(i, j)] = max(0, max(M[kUp] + open, X[kUp] + ext));

        final kLeft = idx(i, j - 1);
        Y[idx(i, j)] = max(0, max(M[kLeft] + open, Y[kLeft] + ext));

        final best = max(mVal, max(X[idx(i, j)], Y[idx(i, j)]));
        if (best > maxScore) {
          maxScore = best;
          maxI = i;
          maxJ = j;
        }
      }
    }

    final sbA = StringBuffer();
    final sbB = StringBuffer();
    int i = maxI, j = maxJ;
    int state =
        M[idx(maxI, maxJ)] >= X[idx(maxI, maxJ)] &&
            M[idx(maxI, maxJ)] >= Y[idx(maxI, maxJ)]
        ? 0
        : (X[idx(maxI, maxJ)] >= Y[idx(maxI, maxJ)] ? 1 : 2);

    while (i > 0 || j > 0) {
      final curBest = max(M[idx(i, j)], max(X[idx(i, j)], Y[idx(i, j)]));
      if (curBest <= 0) break;
      if (state == 0 && i > 0 && j > 0) {
        if (M[idx(i, j)] <= 0) break;
        sbA.write(a[i - 1]);
        sbB.write(b[j - 1]);
        final kDiag = idx(i - 1, j - 1);
        final sub = score(a[i - 1], b[j - 1]);
        final cur = M[idx(i, j)];
        if (cur == M[kDiag] + sub) {
          state = 0;
        } else if (cur == X[kDiag] + sub) {
          state = 1;
        } else {
          state = 2;
        }
        i--;
        j--;
      } else if (state == 1 && i > 0) {
        if (X[idx(i, j)] <= 0) break;
        sbA.write(a[i - 1]);
        sbB.write('-');
        final kUp = idx(i - 1, j);
        final cur = X[idx(i, j)];
        state = (cur == M[kUp] + open) ? 0 : 1;
        i--;
      } else if (state == 2 && j > 0) {
        if (Y[idx(i, j)] <= 0) break;
        sbA.write('-');
        sbB.write(b[j - 1]);
        final kLeft = idx(i, j - 1);
        final cur = Y[idx(i, j)];
        state = (cur == M[kLeft] + open) ? 0 : 2;
        j--;
      } else {
        break;
      }
    }

    return (_reverse(sbA.toString()), _reverse(sbB.toString()), maxScore);
  }

  // ---------------------------------------------------------------------
  // Semi-global / "glocal" ("fitting") alignment: sequence `b` is required
  // to be fully consumed (its own leading/trailing gaps are charged
  // normally), while sequence `a` may freely start/end anywhere around that
  // match with no penalty — i.e. "fit b inside a". This is the standard
  // use case of mapping a short read/primer/domain (`b`) against a longer
  // reference/template/protein (`a`).
  // ---------------------------------------------------------------------

  static (String, String, int, (int, int)) _semiGlobal(
    String a,
    String b,
    int Function(String, String) score,
    AlignmentOptions opt,
  ) {
    final n = a.length;
    final m = b.length;
    final gp = opt.gapModel == GapModel.affine
        ? opt.gapExtendPenalty
        : opt.gapPenalty;
    final width = m + 1;
    final dp = Int32List((n + 1) * width);
    int idx(int i, int j) => i * width + j;

    // Free leading gap in `a` (can start matching `b` anywhere in `a`).
    for (int i = 0; i <= n; i++) {
      dp[idx(i, 0)] = 0;
    }
    // `b` must be fully represented from its own start: normal gap cost.
    for (int j = 0; j <= m; j++) {
      dp[idx(0, j)] = j * gp;
    }

    for (int i = 1; i <= n; i++) {
      final ai = a[i - 1];
      for (int j = 1; j <= m; j++) {
        final diag = dp[idx(i - 1, j - 1)] + score(ai, b[j - 1]);
        final up = dp[idx(i - 1, j)] + gp;
        final left = dp[idx(i, j - 1)] + gp;
        dp[idx(i, j)] = max(diag, max(up, left));
      }
    }

    // `b` must be fully consumed (column m), but `a` may stop anywhere —
    // free trailing gap in `a`.
    int bestI = n;
    int bestScore = dp[idx(n, m)];
    for (int i = 0; i <= n; i++) {
      if (dp[idx(i, m)] > bestScore) {
        bestScore = dp[idx(i, m)];
        bestI = i;
      }
    }

    final sbA = StringBuffer();
    final sbB = StringBuffer();
    int i = bestI, j = m;
    while (j > 0) {
      final cur = dp[idx(i, j)];
      if (i > 0 && cur == dp[idx(i - 1, j - 1)] + score(a[i - 1], b[j - 1])) {
        sbA.write(a[i - 1]);
        sbB.write(b[j - 1]);
        i--;
        j--;
      } else if (i > 0 && cur == dp[idx(i - 1, j)] + gp) {
        sbA.write(a[i - 1]);
        sbB.write('-');
        i--;
      } else {
        sbA.write('-');
        sbB.write(b[j - 1]);
        j--;
      }
    }
    final coreStart = i;
    final coreA = _reverse(sbA.toString());
    final coreB = _reverse(sbB.toString());

    // Re-attach the free, unaligned flanks of `a` (shown against gaps in
    // `b`) so the two returned strings stay the same length and the full
    // extent of `a` remains visible in the UI.
    final leadingA = a.substring(0, coreStart);
    final trailingA = a.substring(bestI);
    final alignedA = leadingA + coreA + trailingA;
    final alignedB =
        _gapsOfLength(leadingA.length) +
        coreB +
        _gapsOfLength(trailingA.length);

    // Identity/similarity should only be computed over the matched core
    // (excludes the free, unpenalized overhanging flanks of `a`).
    final statsRange = (leadingA.length, leadingA.length + coreA.length);
    return (alignedA, alignedB, bestScore, statsRange);
  }

  static String _gapsOfLength(int n) =>
      n <= 0 ? '' : List.filled(n, '-').join();

  // ---------------------------------------------------------------------
  // Result assembly
  // ---------------------------------------------------------------------

  static String _reverse(String s) =>
      String.fromCharCodes(s.codeUnits.reversed);

  static PairwiseAlignmentResult _finishResult(
    String alignedA,
    String alignedB,
    int score,
    AlignmentMode mode,
    AlignmentOptions opt,
    bool banded,
    int elapsedMicros, {
    (int, int)? statsRange,
  }) {
    int matches = 0, gaps = 0, gapOpenings = 0, similar = 0;
    final len = alignedA.length;
    final statsStart = statsRange?.$1 ?? 0;
    final statsEnd = statsRange?.$2 ?? len;
    bool inGap = false;
    for (int k = statsStart; k < statsEnd; k++) {
      final isGap = alignedA[k] == '-' || alignedB[k] == '-';
      if (isGap) {
        gaps++;
        if (!inGap) gapOpenings++;
        inGap = true;
      } else {
        inGap = false;
        if (alignedA[k] == alignedB[k]) {
          matches++;
          similar++;
        } else if (_isSimilar(alignedA[k], alignedB[k], opt.matrixType)) {
          similar++;
        }
      }
    }
    final statsLen = statsEnd - statsStart;
    final identity = statsLen <= 0 ? 0.0 : matches / statsLen * 100;
    final similarity = statsLen <= 0 ? 0.0 : similar / statsLen * 100;
    return PairwiseAlignmentResult(
      alignedSeqA: alignedA,
      alignedSeqB: alignedB,
      score: score,
      identityPercent: identity,
      similarityPercent: similarity,
      gaps: gaps,
      gapOpenings: gapOpenings,
      mode: mode,
      matrixType: opt.matrixType,
      gapModel: opt.gapModel,
      banded: banded,
      elapsedMicros: elapsedMicros,
    );
  }

  static const Set<String> _purines = {'A', 'G'};
  static const Set<String> _pyrimidines = {'C', 'T', 'U'};

  static bool _isSimilar(String x, String y, SubstitutionMatrixType matrix) {
    if (matrix.isProteinMatrix) {
      // "Similar" for protein = positive substitution score (conservative
      // substitution), using BLOSUM62 as the reference scale regardless of
      // which matrix produced the alignment, for a stable definition.
      return SubstitutionMatrices.blosum62(x, y) > 0;
    }
    return (_purines.contains(x) && _purines.contains(y)) ||
        (_pyrimidines.contains(x) && _pyrimidines.contains(y));
  }

  // ---------------------------------------------------------------------
  // Multiple sequence alignment
  // ---------------------------------------------------------------------

  /// Multiple sequence alignment with a selectable method:
  ///  - [MsaMethod.centerStar]: fast heuristic, aligns every sequence
  ///    against the single longest sequence (original behaviour).
  ///  - [MsaMethod.guideTree]: builds a UPGMA guide tree from k-mer
  ///    distances and progressively merges the closest sequences/profiles
  ///    first (ClustalW-style), which handles divergent sets noticeably
  ///    better than the center-star heuristic.
  static MultipleAlignmentResult multipleAlign(
    List<String> names,
    List<String> sequences, {
    AlignmentOptions options = const AlignmentOptions(),
    MsaMethod method = MsaMethod.centerStar,
  }) {
    final sw = Stopwatch()..start();
    if (sequences.isEmpty) {
      return MultipleAlignmentResult(
        names: [],
        alignedSequences: [],
        averageIdentity: 0,
        consensusLength: 0,
        consensusSequence: '',
        method: method,
      );
    }
    if (sequences.length == 1) {
      return MultipleAlignmentResult(
        names: names,
        alignedSequences: [sequences.first],
        averageIdentity: 100,
        consensusLength: sequences.first.length,
        consensusSequence: sequences.first,
        method: method,
        elapsedMicros: sw.elapsedMicroseconds,
      );
    }

    final List<String> aligned;
    final List<int> guideOrder;
    if (method == MsaMethod.guideTree) {
      final r = _progressiveGuideTreeAlign(sequences, options);
      aligned = r.$1;
      guideOrder = r.$2;
    } else {
      aligned = _centerStarAlign(sequences, options);
      guideOrder = const [];
    }

    final maxLen = aligned.map((s) => s.length).reduce(max);
    final padded = aligned.map((s) => s.padRight(maxLen, '-')).toList();

    final consensus = _buildConsensus(padded, maxLen);
    final avgIdentity = _averagePairwiseIdentity(padded, maxLen);

    sw.stop();
    return MultipleAlignmentResult(
      names: names,
      alignedSequences: padded,
      averageIdentity: avgIdentity,
      consensusLength: maxLen,
      consensusSequence: consensus,
      method: method,
      elapsedMicros: sw.elapsedMicroseconds,
      guideOrder: guideOrder,
    );
  }

  /// Original fast heuristic: align every sequence against the single
  /// longest sequence, re-padding previously aligned sequences as the
  /// reference grows.
  static List<String> _centerStarAlign(
    List<String> sequences,
    AlignmentOptions options,
  ) {
    int centerIdx = 0;
    for (int i = 1; i < sequences.length; i++) {
      if (sequences[i].length > sequences[centerIdx].length) centerIdx = i;
    }

    List<String> aligned = List.filled(sequences.length, '');
    aligned[centerIdx] = sequences[centerIdx];

    for (int i = 0; i < sequences.length; i++) {
      if (i == centerIdx) continue;
      final res = globalAlign(
        aligned[centerIdx],
        sequences[i],
        options: options,
      );
      aligned[centerIdx] = res.alignedSeqA;
      aligned[i] = res.alignedSeqB;
      for (int k = 0; k < sequences.length; k++) {
        if (k != i && k != centerIdx && aligned[k].isNotEmpty) {
          if (aligned[k].length < aligned[centerIdx].length) {
            aligned[k] = aligned[k].padRight(aligned[centerIdx].length, '-');
          }
        }
      }
    }
    return aligned;
  }

  /// Progressive alignment guided by a UPGMA tree built from fast k-mer
  /// distances. Sequences/profiles are merged pairwise, closest first;
  /// profile vs profile merges are approximated by aligning each profile's
  /// representative (first) row and propagating the resulting gap pattern
  /// to every row of both profiles — a standard, tractable approximation
  /// of true profile-profile alignment for a desktop/tablet-scale tool.
  static (List<String>, List<int>) _progressiveGuideTreeAlign(
    List<String> sequences,
    AlignmentOptions options,
  ) {
    final n = sequences.length;
    final dist = _kmerDistanceMatrix(sequences);

    // profiles[i] = list of row-strings currently in this cluster, in
    // original-index order given by members[i].
    final List<List<String>> profiles = [
      for (final s in sequences) [s],
    ];
    final List<List<int>> members = [
      for (int i = 0; i < n; i++) [i],
    ];
    final List<int> active = List.generate(n, (i) => i);
    final List<List<double>> d = dist.map((r) => List<double>.from(r)).toList();
    final List<int> mergeOrder = [];

    while (active.length > 1) {
      double best = double.infinity;
      int bi = -1, bj = -1;
      for (int a = 0; a < active.length; a++) {
        for (int b = a + 1; b < active.length; b++) {
          final i = active[a], j = active[b];
          if (d[i][j] < best) {
            best = d[i][j];
            bi = i;
            bj = j;
          }
        }
      }
      if (bi == -1) break;

      // Align representative rows of each profile.
      final repA = profiles[bi][0];
      final repB = profiles[bj][0];
      final res = globalAlign(repA, repB, options: options);

      final newProfileA = _propagateGaps(profiles[bi], repA, res.alignedSeqA);
      final newProfileB = _propagateGaps(profiles[bj], repB, res.alignedSeqB);
      final mergedProfile = [...newProfileA, ...newProfileB];
      final mergedMembers = [...members[bi], ...members[bj]];

      final newIdx = profiles.length;
      profiles.add(mergedProfile);
      members.add(mergedMembers);
      mergeOrder.add(newIdx);

      // Average-linkage distance to remaining active clusters.
      final sizeI = members[bi].length;
      final sizeJ = members[bj].length;
      final Map<int, double> newDist = {};
      for (final idx in active) {
        if (idx == bi || idx == bj) continue;
        newDist[idx] =
            (d[bi][idx] * sizeI + d[bj][idx] * sizeJ) / (sizeI + sizeJ);
      }
      active.remove(bi);
      active.remove(bj);
      for (final row in d) {
        row.add(0);
      }
      d.add(List<double>.filled(d[0].length, 0, growable: true));
      newDist.forEach((idx, v) {
        d[newIdx][idx] = v;
        d[idx][newIdx] = v;
      });
      active.add(newIdx);
    }

    final finalProfile = profiles[active.first];
    final finalMembers = members[active.first];
    final maxLen = finalProfile.map((s) => s.length).fold(0, max);
    final padded = finalProfile.map((s) => s.padRight(maxLen, '-')).toList();

    // Re-order back to the caller's original sequence order.
    final out = List<String>.filled(n, '');
    for (int k = 0; k < finalMembers.length; k++) {
      out[finalMembers[k]] = padded[k];
    }
    return (out, mergeOrder);
  }

  /// Given a profile's old rows (all sharing [oldRepLength]) and the newly
  /// aligned version of its representative row (which may have inserted
  /// gaps), insert matching gap columns into every row of the profile so
  /// they all stay the same length and column-consistent.
  static List<String> _propagateGaps(
    List<String> oldRows,
    String oldRep,
    String newRep,
  ) {
    // Walk newRep; whenever we consume a non-gap char it corresponds to the
    // next char of oldRep (and thus the next column of every old row).
    // Whenever newRep has a gap, insert a gap at that column in every row.
    final result = List.generate(oldRows.length, (_) => StringBuffer());
    int oldCol = 0;
    for (int k = 0; k < newRep.length; k++) {
      if (newRep[k] == '-') {
        for (final buf in result) {
          buf.write('-');
        }
      } else {
        for (int r = 0; r < oldRows.length; r++) {
          result[r].write(
            oldCol < oldRows[r].length ? oldRows[r][oldCol] : '-',
          );
        }
        oldCol++;
      }
    }
    return result.map((b) => b.toString()).toList();
  }

  static List<List<double>> _kmerDistanceMatrix(
    List<String> sequences, {
    int k = 5,
  }) {
    final n = sequences.length;
    final sets = sequences.map((s) {
      final set = <String>{};
      final kk = min(k, s.length);
      if (kk <= 0) return set;
      for (int i = 0; i + kk <= s.length; i++) {
        set.add(s.substring(i, i + kk));
      }
      return set;
    }).toList();

    final matrix = List.generate(n, (_) => List<double>.filled(n, 0));
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        final a = sets[i], b = sets[j];
        double dist;
        if (a.isEmpty || b.isEmpty) {
          dist = 1.0;
        } else {
          final inter = a.intersection(b).length;
          final union = a.union(b).length;
          dist = union == 0 ? 1.0 : 1.0 - inter / union;
        }
        matrix[i][j] = dist;
        matrix[j][i] = dist;
      }
    }
    return matrix;
  }

  static String _buildConsensus(List<String> aligned, int maxLen) {
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
    return sb.toString();
  }

  static double _averagePairwiseIdentity(List<String> aligned, int maxLen) {
    double totalIdentity = 0;
    int pairCount = 0;
    for (int i = 0; i < aligned.length; i++) {
      for (int j = i + 1; j < aligned.length; j++) {
        int matches = 0;
        int compared = 0;
        for (int k = 0; k < maxLen; k++) {
          final ci = k < aligned[i].length ? aligned[i][k] : '-';
          final cj = k < aligned[j].length ? aligned[j][k] : '-';
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
    return pairCount == 0 ? 0.0 : totalIdentity / pairCount;
  }
}
