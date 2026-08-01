import '../models/analysis_models.dart';
import 'sequence_engine.dart';

/// RNA-focused analysis: DNA->RNA transcription, RNA class identification
/// heuristics, and a simplified secondary-structure prediction.
///
/// HONESTY NOTE: the secondary-structure predictor implements the classic
/// Nussinov base-pair maximization algorithm (maximizes the number of
/// Watson-Crick/wobble pairs). It is NOT a full thermodynamic folding model
/// like ViennaRNA/mfold (which use nearest-neighbor free-energy
/// parameters) — treat the output as an indicative/simplified structure,
/// not a validated free-energy-minimized fold.
class RnaEngine {
  /// Transcribes a coding (sense) strand DNA sequence directly into mRNA
  /// (same order, T -> U).
  static String transcribeCodingStrand(String dnaSeq) {
    return dnaSeq.toUpperCase().replaceAll('T', 'U');
  }

  /// Transcribes from a template (antisense) strand DNA sequence: RNA
  /// polymerase reads the template 3'->5' and synthesizes complementary
  /// RNA 5'->3', which is equivalent to taking the reverse complement of a
  /// template strand written 5'->3' and converting T -> U.
  static String transcribeFromTemplateStrand(String templateDnaSeq) {
    final rc = SequenceEngine.reverseComplement(templateDnaSeq.toUpperCase());
    return rc.replaceAll('T', 'U');
  }

  static int _polyATailLength(String seq) {
    int count = 0;
    for (int i = seq.length - 1; i >= 0; i--) {
      if (seq[i] == 'A') {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  static bool _withinRange(int len, int lo, int hi) => len >= lo && len <= hi;

  static int _longestOrfAaLength(String protein) {
    int best = 0;
    for (final part in protein.split('*')) {
      final mIdx = part.indexOf('M');
      if (mIdx >= 0) {
        final len = part.length - mIdx;
        if (len > best) best = len;
      }
    }
    return best;
  }

  /// Heuristic RNA class identification based on length, poly-A signal and
  /// coding potential (ORF length). This is a simplified classifier for
  /// triage purposes, not a substitute for tools like Rfam/Infernal.
  static RnaClassificationResult classify(String rawSeq) {
    final seq = rawSeq.toUpperCase().replaceAll('T', 'U');
    final len = seq.length;
    final reasons = <String>[];

    final polyA = _polyATailLength(seq);
    final hasPolyA = polyA >= 10;
    if (hasPolyA) {
      reasons.add(
        'Poly-A tail detected ($polyA consecutive A at the 3\' end).',
      );
    }

    final dnaLike = seq.replaceAll('U', 'T');
    final protein = SequenceEngine.translate(dnaLike);
    final orfLen = _longestOrfAaLength(protein);
    final hasOrf = orfLen >= 30;
    if (hasOrf) {
      reasons.add(
        'Long open reading frame detected (~$orfLen aa) suggesting protein-coding potential.',
      );
    }

    RnaTypeGuess guess;
    double confidence;

    if (len >= 18 && len <= 26) {
      guess = RnaTypeGuess.miRNA;
      confidence = 55;
      reasons.add(
        'Length ($len nt) matches the typical mature microRNA size range (18-26 nt).',
      );
    } else if (len >= 60 && len <= 100) {
      guess = RnaTypeGuess.tRNA;
      confidence = 40;
      reasons.add(
        'Length ($len nt) is consistent with tRNA (~70-90 nt); a cloverleaf '
        'secondary structure (4 stems) would confirm this.',
      );
    } else if (_withinRange(len, 100, 135) ||
        _withinRange(len, 1400, 1650) ||
        _withinRange(len, 2700, 3100)) {
      guess = RnaTypeGuess.rRNA;
      confidence = 38;
      reasons.add(
        'Length ($len nt) falls within a known ribosomal RNA size class '
        '(5S ~120nt / 16S-18S ~1500nt / 23S-28S ~2900nt).',
      );
    } else if (hasOrf && len > 200) {
      guess = RnaTypeGuess.mRNA;
      confidence = hasPolyA ? 75 : 55;
      reasons.add(
        hasPolyA
            ? 'Sufficient length, coding potential and poly-A tail — strong mRNA signature.'
            : 'Sufficient length with coding potential — likely mRNA (no poly-A detected, may be a partial/immature transcript).',
      );
    } else if (len > 200 && !hasOrf) {
      guess = RnaTypeGuess.lncRNA;
      confidence = 35;
      reasons.add(
        'Length ($len nt) > 200 nt without a substantial ORF — consistent '
        'with long non-coding RNA (lncRNA).',
      );
    } else if (len >= 20 && len <= 30 && !hasOrf) {
      guess = RnaTypeGuess.siRNA;
      confidence = 25;
      reasons.add(
        'Short length ($len nt) without coding potential — could be a '
        'small interfering RNA (siRNA) or an unprocessed miRNA precursor fragment.',
      );
    } else {
      guess = RnaTypeGuess.unknown;
      confidence = 15;
      reasons.add(
        'No strong length/composition signature confidently matched a '
        'known RNA class — manual inspection or database comparison recommended.',
      );
    }

    return RnaClassificationResult(
      guess: guess,
      confidence: confidence,
      reasons: reasons,
      hasPolyATail: hasPolyA,
      polyALength: polyA,
      hasOrf: hasOrf,
    );
  }

  /// Simplified RNA secondary-structure prediction using the classic
  /// Nussinov base-pair maximization dynamic programming algorithm.
  /// Input longer than [maxLength] is truncated for performance —
  /// full-genome/long-transcript folding requires specialized tools.
  static RnaFoldResult predictSecondaryStructure(
    String rawSeq, {
    int maxLength = 350,
    int minLoop = 3,
  }) {
    final full = rawSeq.toUpperCase().replaceAll('T', 'U');
    final seq = full.length > maxLength ? full.substring(0, maxLength) : full;
    final n = seq.length;
    if (n < minLoop + 2) {
      return RnaFoldResult(
        sequence: seq,
        dotBracket: '.' * n,
        pairCount: 0,
        pseudoFreeEnergy: 0,
      );
    }

    bool canPair(String a, String b) {
      final p = a + b;
      return p == 'AU' ||
          p == 'UA' ||
          p == 'GC' ||
          p == 'CG' ||
          p == 'GU' ||
          p == 'UG';
    }

    final dp = List.generate(n, (_) => List<int>.filled(n, 0));
    for (int span = minLoop + 1; span < n; span++) {
      for (int i = 0; i + span < n; i++) {
        final j = i + span;
        int best = dp[i + 1][j]; // leave i unpaired
        for (int k = i + minLoop + 1; k <= j; k++) {
          if (canPair(seq[i], seq[k])) {
            final left = (k - 1 >= i + 1) ? dp[i + 1][k - 1] : 0;
            final right = (k + 1 <= j) ? dp[k + 1][j] : 0;
            final val = left + 1 + right;
            if (val > best) best = val;
          }
        }
        dp[i][j] = best;
      }
    }

    final pairs = <int, int>{};
    void backtrack(int i, int j) {
      if (i >= j) return;
      if (dp[i][j] == dp[i + 1][j]) {
        backtrack(i + 1, j);
        return;
      }
      for (int k = i + minLoop + 1; k <= j; k++) {
        if (canPair(seq[i], seq[k])) {
          final left = (k - 1 >= i + 1) ? dp[i + 1][k - 1] : 0;
          final right = (k + 1 <= j) ? dp[k + 1][j] : 0;
          if (dp[i][j] == left + 1 + right) {
            pairs[i] = k;
            if (i + 1 <= k - 1) backtrack(i + 1, k - 1);
            if (k + 1 <= j) backtrack(k + 1, j);
            return;
          }
        }
      }
    }

    backtrack(0, n - 1);
    final brackets = List.filled(n, '.');
    pairs.forEach((i, j) {
      brackets[i] = '(';
      brackets[j] = ')';
    });

    return RnaFoldResult(
      sequence: seq,
      dotBracket: brackets.join(),
      pairCount: pairs.length,
      pseudoFreeEnergy: -1.0 * pairs.length,
    );
  }
}
