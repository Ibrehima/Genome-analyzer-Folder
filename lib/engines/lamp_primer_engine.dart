import '../models/analysis_models.dart';
import 'primer_engine.dart';
import 'sequence_engine.dart';

/// Local LAMP (Loop-mediated isothermal AMPlification) primer design engine.
///
/// Implements the standard LAMP primer topology described by Notomi et al.
/// (2000) and the loop-primer extension of Nagamine et al. (2002):
///   - 2 outer primers: F3, B3
///   - 2 composite inner primers: FIP (= F1c + F2), BIP (= B1c + B2)
///   - 2 optional loop primers: LF, LB (accelerate the reaction)
///
/// Region layout on the *sense* (input) strand, read 5'->3':
///   F3 -- F2 -- F1 -- [amplicon core / loop region] -- B1 -- B2 -- B3
///
/// Strand logic (derived from standard primer-extension chemistry):
///   F3  = identical copy of the F3 region
///   F2  = identical copy of the F2 region
///   F1c = reverse complement of the F1 region   -> FIP = F1c + F2
///   B1c = identical copy of the B1 region
///   B2  = reverse complement of the B2 region
///   B3  = reverse complement of the B3 region   -> BIP = B1c + B2
///
/// This is a **local heuristic design tool** (same spirit as the Primer3-style
/// PCR primer engine elsewhere in this app) — it is NOT a substitute for a
/// dedicated LAMP design tool (e.g. PrimerExplorer V5, NEB LAMP Primer Design
/// Tool) or for wet-lab optimization. Always re-verify candidates with such a
/// tool before ordering oligos.
class LampPrimerEngine {
  static const String disclaimer =
      'LAMP primer sets are generated with local heuristics following the standard '
      'F3/F2/F1c-FIP + B1c/B2/B3-BIP (+ optional LF/LB loop primers) topology. '
      'This is an approximate design aid, not a replacement for a dedicated LAMP '
      'design tool (e.g. PrimerExplorer V5, NEB LAMP Primer Design Tool) or for '
      'wet-lab validation — always re-check Tm, secondary structure and '
      'specificity before ordering primers.';

  /// A handful of representative lengths (instead of an exhaustive range) to
  /// keep the search space tractable for a desktop/tablet app.
  static List<int> _lenOptions(int minLen, int maxLen) {
    final opts = <int>{minLen, ((minLen + maxLen) / 2).round(), maxLen};
    return opts.where((l) => l >= minLen && l <= maxLen).toList()..sort();
  }

  static bool _hasRepeat(String s) =>
      RegExp(r'(A{5,}|T{5,}|G{5,}|C{5,})').hasMatch(s);

  /// Basic acceptability filter shared by all 6 primer-region pieces.
  static bool _acceptable(String s) {
    if (_hasRepeat(s)) return false;
    final gc = SequenceEngine.gcContent(s);
    if (gc < 30 || gc > 70) return false;
    return true;
  }

  /// Builds a scored [LampPrimerPiece] for a template substring, tagging it
  /// with the correct oligo sequence (identical copy or reverse complement)
  /// depending on [useReverseComplement].
  static LampPrimerPiece? _buildPiece(
    String template,
    int start,
    int len,
    String role, {
    bool useReverseComplement = false,
  }) {
    if (start < 0 || start + len > template.length) return null;
    final region = template.substring(start, start + len);
    if (!_acceptable(region)) return null;
    final oligo = useReverseComplement
        ? SequenceEngine.reverseComplement(region)
        : region;
    return LampPrimerPiece(
      role: role,
      sequence: oligo,
      templateStart: start,
      templateEnd: start + len,
      gcContent: SequenceEngine.gcContent(oligo),
      meltingTemp: PrimerEngine.meltingTemp(oligo),
    );
  }

  /// Finds the best-scoring outer+inner combination for one side (F-side or
  /// B-side) starting at [zoneStart], scanning forward. Returns null if no
  /// acceptable combination is found within [maxScan] template positions.
  static _SideResult? _bestSide({
    required String template,
    required int zoneStart,
    required int outerMinLen,
    required int outerMaxLen,
    required int innerMinLen,
    required int innerMaxLen,
    required int maxGapOuterInner,
    required int maxGapInnerInner,
    required int maxScan,
    required String outerRole,
    required String innerRole,
    required String tailRole,
    required bool outerIsRC,
    required bool innerIsRC,
    required bool tailIsRC,
  }) {
    final outerLens = _lenOptions(outerMinLen, outerMaxLen);
    final innerLens = _lenOptions(innerMinLen, innerMaxLen);
    double bestScore = -1;
    _SideResult? best;

    // NOTE on performance: hairpin-risk is O(len^2) and was previously being
    // recomputed for the same outer/inner piece on every combination of the
    // deeper gap loops. Hoisting each piece's hairpin-risk calculation up to
    // the loop level where the piece is actually built (instead of the
    // innermost loop) cuts redundant work by roughly an order of magnitude
    // on typical template lengths, without changing the search space.
    final scanLimit = (zoneStart + maxScan).clamp(0, template.length);
    for (int outerStart = zoneStart; outerStart < scanLimit; outerStart++) {
      for (final outerLen in outerLens) {
        final outerPiece = _buildPiece(
          template,
          outerStart,
          outerLen,
          outerRole,
          useReverseComplement: outerIsRC,
        );
        if (outerPiece == null) continue;
        final outerHp = PrimerEngine.hairpinRisk(outerPiece.sequence);
        final outerEnd = outerStart + outerLen;

        for (int gap1 = 0; gap1 <= maxGapOuterInner; gap1++) {
          final innerStart = outerEnd + gap1;
          for (final innerLen in innerLens) {
            final innerPiece = _buildPiece(
              template,
              innerStart,
              innerLen,
              innerRole,
              useReverseComplement: innerIsRC,
            );
            if (innerPiece == null) continue;
            final innerHp = PrimerEngine.hairpinRisk(innerPiece.sequence);
            final innerEnd = innerStart + innerLen;

            for (int gap2 = 0; gap2 <= maxGapInnerInner; gap2++) {
              final tailStart = innerEnd + gap2;
              for (final tailLen in innerLens) {
                final tailPiece = _buildPiece(
                  template,
                  tailStart,
                  tailLen,
                  tailRole,
                  useReverseComplement: tailIsRC,
                );
                if (tailPiece == null) continue;
                final tailHp = PrimerEngine.hairpinRisk(tailPiece.sequence);

                final tmSpread = _tmSpread([
                  outerPiece.meltingTemp,
                  innerPiece.meltingTemp,
                  tailPiece.meltingTemp,
                ]);
                final hpRisk = (outerHp + innerHp + tailHp) / 3.0;
                double score = 100;
                score -= tmSpread * 3; // penalize uneven Tm across the trio
                score -= hpRisk * 25;
                // Mild preference for tighter, more typical gaps.
                score -= (gap1 + gap2) * 0.3;
                score = score.clamp(0, 100);

                if (score > bestScore) {
                  bestScore = score;
                  best = _SideResult(
                    outer: outerPiece,
                    inner: innerPiece,
                    tail: tailPiece,
                    score: score,
                  );
                }
              }
            }
          }
        }
      }
    }
    return best;
  }

  static double _tmSpread(List<double> tms) {
    final mn = tms.reduce((a, b) => a < b ? a : b);
    final mx = tms.reduce((a, b) => a > b ? a : b);
    return mx - mn;
  }

  /// Attempts to find a loop primer within a template window, biased toward
  /// [preferReverseComplement] orientation (LF behaves like a reverse-type
  /// primer relative to the F2-F1 gap; LB behaves like a forward/identical
  /// -type primer relative to the B1-B2 gap).
  static LampPrimerPiece? _findLoopPrimer(
    String template,
    int windowStart,
    int windowEnd,
    String role,
    bool useReverseComplement,
  ) {
    if (windowEnd - windowStart < 15) return null;
    LampPrimerPiece? best;
    double bestScore = -1;
    for (final len in [18, 20]) {
      if (windowStart + len > windowEnd) continue;
      // Try a couple of offsets within the window rather than every base,
      // to keep this fast — the loop region is usually short anyway.
      final maxOffset = (windowEnd - windowStart - len).clamp(0, 20);
      for (int off = 0; off <= maxOffset; off += 4) {
        final piece = _buildPiece(
          template,
          windowStart + off,
          len,
          role,
          useReverseComplement: useReverseComplement,
        );
        if (piece == null) continue;
        final hp = PrimerEngine.hairpinRisk(piece.sequence);
        final score = 100 - hp * 30;
        if (score > bestScore) {
          bestScore = score;
          best = piece;
        }
      }
    }
    return best;
  }

  /// Designs candidate LAMP primer sets for [template].
  ///
  /// [coreSizeRange] controls the amplicon "core" (F1-to-B1 distance), which
  /// also doubles as the search window for optional loop primers when
  /// [includeLoopPrimers] is true.
  static List<LampPrimerSet> designLampPrimers(
    String template, {
    int outerMinLen = 18,
    int outerMaxLen = 22,
    int innerMinLen = 18,
    int innerMaxLen = 22,
    List<int> coreSizeRange = const [40, 80],
    bool includeLoopPrimers = true,
    int maxSets = 6,
  }) {
    final results = <LampPrimerSet>[];
    if (template.length < 150) return results; // too short for LAMP topology

    final coreMin = coreSizeRange.first;
    final coreMax = coreSizeRange.last;
    // Scan the template in a moderate number of "core windows" to keep the
    // combinatorics bounded on longer inputs.
    final usableLen = template.length;
    final fZoneScan = (usableLen * 0.5).round().clamp(30, 220);

    final fSide = _bestSide(
      template: template,
      zoneStart: 0,
      outerMinLen: outerMinLen,
      outerMaxLen: outerMaxLen,
      innerMinLen: innerMinLen,
      innerMaxLen: innerMaxLen,
      maxGapOuterInner: 2,
      maxGapInnerInner: 2,
      maxScan: fZoneScan,
      outerRole: 'F3',
      innerRole: 'F2',
      tailRole: 'F1c',
      outerIsRC: false,
      innerIsRC: false,
      tailIsRC: true, // F1c = reverse complement of F1 region
    );
    if (fSide == null) return results;

    // B-side must start after F-side finishes, with room for the core gap.
    for (final coreSize in [
      coreMin,
      ((coreMin + coreMax) / 2).round(),
      coreMax,
    ]) {
      final bZoneStart = fSide.tail.templateEnd + coreSize;
      if (bZoneStart >= template.length - (outerMinLen + innerMinLen * 2)) {
        continue;
      }
      final bZoneScan = (template.length - bZoneStart).clamp(
        30,
        (usableLen * 0.5).round().clamp(30, 220),
      );

      final bSide = _bestSide(
        template: template,
        zoneStart: bZoneStart,
        outerMinLen: innerMinLen, // B1 uses "inner" length range
        outerMaxLen: innerMaxLen,
        innerMinLen: innerMinLen,
        innerMaxLen: innerMaxLen,
        maxGapOuterInner: 2,
        maxGapInnerInner: 2,
        maxScan: bZoneScan,
        outerRole: 'B1',
        innerRole: 'B2',
        tailRole: 'B3',
        outerIsRC: false, // B1c = identical copy of B1 region
        innerIsRC: true, // B2 = reverse complement of B2 region
        tailIsRC: true, // B3 = reverse complement of B3 region
      );
      if (bSide == null) continue;

      final f3 = fSide.outer;
      final f2 = fSide.inner;
      final f1c = fSide.tail;
      final b1c = bSide.outer; // role label already 'B1'
      final b2 = bSide.inner;
      final b3 = bSide.tail;

      final fip = '${f1c.sequence}${f2.sequence}';
      final bip = '${b1c.sequence}${b2.sequence}';

      LampPrimerPiece? lf;
      LampPrimerPiece? lb;
      final notes = <String>[];
      if (includeLoopPrimers) {
        lf = _findLoopPrimer(
          template,
          f2.templateEnd,
          f1c.templateStart,
          'LF',
          true,
        );
        lb = _findLoopPrimer(
          template,
          b1c.templateEnd,
          b2.templateStart,
          'LB',
          false,
        );
        if (lf == null || lb == null) {
          notes.add(
            'No suitable loop primer found in the current gaps — try a '
            'larger core/gap size or disable loop primers.',
          );
        }
      }

      final crossDim = PrimerEngine.crossDimerRisk(fip, bip);
      final tmAll = [
        f3.meltingTemp,
        f2.meltingTemp,
        f1c.meltingTemp,
        b1c.meltingTemp,
        b2.meltingTemp,
        b3.meltingTemp,
      ];
      final spread = _tmSpread(tmAll);
      double overallScore = (fSide.score + bSide.score) / 2;
      overallScore -= spread * 1.5;
      overallScore -= crossDim * 15;
      // Mild bonus for having working loop primers.
      if (includeLoopPrimers && lf != null && lb != null) overallScore += 5;
      overallScore = overallScore.clamp(0, 100);

      results.add(
        LampPrimerSet(
          f3: f3,
          f2: f2,
          f1c: f1c,
          b1c: b1c,
          b2: b2,
          b3: b3,
          lf: lf,
          lb: lb,
          fip: fip,
          bip: bip,
          totalSpan: b3.templateEnd - f3.templateStart,
          ampliconCoreSize: b1c.templateStart - f1c.templateEnd,
          score: overallScore,
          notes: notes,
        ),
      );
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(maxSets).toList();
  }
}

class _SideResult {
  final LampPrimerPiece outer;
  final LampPrimerPiece inner;
  final LampPrimerPiece tail;
  final double score;
  _SideResult({
    required this.outer,
    required this.inner,
    required this.tail,
    required this.score,
  });
}
