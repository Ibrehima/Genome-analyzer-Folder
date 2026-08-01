import 'dart:math';
import '../models/analysis_models.dart';
import 'sequence_engine.dart';

/// Local primer design engine (Primer3-style heuristics).
class PrimerEngine {
  static double meltingTemp(String primer) {
    // Basic salt-adjusted formula (Wallace rule for short primers, or
    // GC-based formula for longer ones).
    final len = primer.length;
    if (len == 0) return 0;
    if (len < 14) {
      final a = primer.split('').where((c) => c == 'A' || c == 'T').length;
      final gc = primer.split('').where((c) => c == 'G' || c == 'C').length;
      return 2.0 * a + 4.0 * gc;
    }
    final gcPct = SequenceEngine.gcContent(primer);
    // Modified formula accounting for length: Tm = 81.5 + 0.41*(%GC) - 675/len
    return 81.5 + 0.41 * gcPct - 675.0 / len;
  }

  /// Heuristic hairpin risk: looks for internal reverse-complement self matches.
  static double hairpinRisk(String primer) {
    int maxMatch = 0;
    final rc = SequenceEngine.reverseComplement(primer);
    for (int i = 0; i < primer.length - 3; i++) {
      for (int j = 0; j < rc.length - 3; j++) {
        int m = 0;
        while (i + m < primer.length &&
            j + m < rc.length &&
            primer[i + m] == rc[j + m] &&
            (i - j).abs() > 3) {
          m++;
        }
        if (m > maxMatch) maxMatch = m;
      }
    }
    return (maxMatch / max(primer.length, 1)).clamp(0.0, 1.0);
  }

  /// Heuristic self-dimer risk: 3' end complementarity to itself.
  static double selfDimerRisk(String primer) {
    final rc = SequenceEngine.reverseComplement(primer);
    int best = 0;
    for (int shift = -primer.length + 1; shift < primer.length; shift++) {
      int matches = 0;
      for (int i = 0; i < primer.length; i++) {
        final j = i + shift;
        if (j < 0 || j >= rc.length) continue;
        if (primer[i] == rc[j]) matches++;
      }
      if (matches > best) best = matches;
    }
    return (best / max(primer.length, 1)).clamp(0.0, 1.0);
  }

  static double crossDimerRisk(String a, String b) {
    final rcB = SequenceEngine.reverseComplement(b);
    int best = 0;
    for (int shift = -a.length + 1; shift < a.length; shift++) {
      int matches = 0;
      for (int i = 0; i < a.length; i++) {
        final j = i + shift;
        if (j < 0 || j >= rcB.length) continue;
        if (a[i] == rcB[j]) matches++;
      }
      if (matches > best) best = matches;
    }
    return (best / max(a.length, 1)).clamp(0.0, 1.0);
  }

  static bool _hasRepeat(String primer) {
    // reject primers with mononucleotide runs >= 5
    return RegExp(r'(A{5,}|T{5,}|G{5,}|C{5,})').hasMatch(primer);
  }

  static double _scoreCandidate(
    double gc,
    double tm,
    double hairpin,
    double dimer,
  ) {
    double score = 100;
    // Ideal GC 40-60%
    if (gc < 40 || gc > 60) score -= (gc < 40 ? 40 - gc : gc - 60) * 1.5;
    // Ideal Tm 55-65
    if (tm < 55 || tm > 65) score -= (tm < 55 ? 55 - tm : tm - 65) * 1.2;
    score -= hairpin * 30;
    score -= dimer * 20;
    return score.clamp(0, 100);
  }

  /// Scans a template sequence for candidate primers of given length range.
  static List<PrimerCandidate> scanCandidates(
    String template, {
    int minLen = 18,
    int maxLen = 24,
    int maxCandidates = 60,
  }) {
    final List<PrimerCandidate> candidates = [];
    for (int len = minLen; len <= maxLen; len++) {
      for (int i = 0; i + len <= template.length; i++) {
        final sub = template.substring(i, i + len);
        if (_hasRepeat(sub)) continue;
        final gc = SequenceEngine.gcContent(sub);
        if (gc < 30 || gc > 70) continue;
        final tm = meltingTemp(sub);
        final hp = hairpinRisk(sub);
        final dim = selfDimerRisk(sub);
        final score = _scoreCandidate(gc, tm, hp, dim);
        if (score < 40) continue;
        candidates.add(
          PrimerCandidate(
            sequence: sub,
            startPosition: i,
            gcContent: gc,
            meltingTemp: tm,
            hairpinRisk: hp,
            selfDimerRisk: dim,
            score: score,
          ),
        );
      }
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(maxCandidates).toList();
  }

  /// Designs forward/reverse primer pairs for a given template.
  static List<PrimerPairResult> designPrimerPairs(
    String template, {
    int minLen = 18,
    int maxLen = 24,
    int minProductSize = 100,
    int maxProductSize = 1000,
    int maxPairs = 10,
  }) {
    final fwdCandidates = scanCandidates(
      template,
      minLen: minLen,
      maxLen: maxLen,
    );
    final rcTemplate = SequenceEngine.reverseComplement(template);
    final revCandidatesRaw = scanCandidates(
      rcTemplate,
      minLen: minLen,
      maxLen: maxLen,
    );

    final List<PrimerPairResult> pairs = [];
    for (final fwd in fwdCandidates) {
      for (final revRaw in revCandidatesRaw) {
        // Position of reverse primer in original template coordinates
        final revEndInOriginal = template.length - revRaw.startPosition;
        final productSize = revEndInOriginal - fwd.startPosition;
        if (productSize < minProductSize || productSize > maxProductSize) {
          continue;
        }
        final tmDiff = (fwd.meltingTemp - revRaw.meltingTemp).abs();
        if (tmDiff > 5) continue;
        final crossDim = crossDimerRisk(fwd.sequence, revRaw.sequence);
        final pairScore =
            (fwd.score + revRaw.score) / 2 - tmDiff * 2 - crossDim * 15;
        pairs.add(
          PrimerPairResult(
            forward: fwd,
            reverse: revRaw,
            productSize: productSize,
            tmDifference: tmDiff,
            crossDimerRisk: crossDim,
            pairScore: pairScore.clamp(0, 100),
          ),
        );
      }
    }
    pairs.sort((a, b) => b.pairScore.compareTo(a.pairScore));
    return pairs.take(maxPairs).toList();
  }
}
