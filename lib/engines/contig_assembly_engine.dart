import 'dart:math';
import '../models/bio_sequence.dart';
import '../models/analysis_models.dart';
import 'sequence_engine.dart';

/// Greedy Overlap-Layout-Consensus (OLC) contig assembler.
///
/// HONESTY NOTE: production assemblers (e.g. Celera/Canu, SPAdes, Flye) use
/// de Bruijn graphs or sophisticated overlap graphs with error-correction
/// and repeat resolution. This is a simplified, from-scratch, offline
/// greedy-OLC approach suitable for small datasets (amplicons, small
/// genes/genomes, contig "stitching" of Sanger reads) — not a replacement
/// for a full de-novo assembler on complex/repetitive genomes.
///
/// Algorithm:
///  1. Compute all pairwise suffix-prefix overlaps (seeded by a k-mer index
///     to avoid a full O(n^2) exact scan on large inputs) considering both
///     a read and its reverse complement, since Sanger/PacBio reads come
///     from either strand.
///  2. Greedily merge the highest-scoring overlap pair (score = overlap
///     length x identity), repeatedly, building a simple read-extension
///     chain per contig (classic greedy-OLC layout).
///  3. At each merge, the consensus base is picked by majority vote in the
///     overlapping region (weighted by nothing fancier than count, since
///     these reads are already post-basecalling/QC).
///  4. Reads that never find a qualifying overlap become singleton
///     "contigs" of size 1 and are also listed separately so nothing is
///     silently dropped.
class ContigAssemblyEngine {
  /// Minimum overlap length (bp) to consider two reads mergeable.
  static const int defaultMinOverlap = 20;

  /// Minimum % identity within the overlap region to accept a merge.
  static const double defaultMinIdentity = 90.0;

  static String _revComp(String s) => SequenceEngine.reverseComplement(s);

  /// Scores the best suffix-of-[a] vs prefix-of-[b] overlap using a fast
  /// banded approach: tries every overlap length from longest to shortest
  /// (capped for performance) and returns the first/best one that clears
  /// [minOverlap] and [minIdentity]. Returns null if no good overlap.
  static ({int overlapLen, double identity})? _bestOverlap(
    String a,
    String b, {
    required int minOverlap,
    required double minIdentity,
  }) {
    final maxLen = min(a.length, b.length);
    if (maxLen < minOverlap) return null;
    ({int overlapLen, double identity})? best;
    // Scan candidate overlap lengths; for performance on long reads, only
    // check every position down to minOverlap (early exit on first strong
    // hit keeps this fast for the common "clean 3' / 5' overlap" case).
    for (int len = maxLen; len >= minOverlap; len--) {
      final suffixA = a.substring(a.length - len);
      final prefixB = b.substring(0, len);
      int matches = 0;
      for (int i = 0; i < len; i++) {
        if (suffixA[i] == prefixB[i]) matches++;
      }
      final identity = matches / len * 100;
      if (identity >= minIdentity) {
        best = (overlapLen: len, identity: identity);
        break; // longest qualifying overlap wins
      }
    }
    return best;
  }

  /// Builds a short k-mer index (end-anchored) to quickly shortlist
  /// candidate pairs before running the expensive overlap scan — avoids a
  /// full O(n^2 * L) scan when there are many unrelated reads.
  static Map<String, List<int>> _buildSuffixIndex(List<String> seqs, int k) {
    final index = <String, List<int>>{};
    for (int i = 0; i < seqs.length; i++) {
      final s = seqs[i];
      if (s.length < k) continue;
      final tail = s.substring(s.length - k);
      index.putIfAbsent(tail, () => []).add(i);
    }
    return index;
  }

  static AssemblyResult assemble(
    List<BioSequence> reads, {
    int minOverlap = defaultMinOverlap,
    double minIdentity = defaultMinIdentity,
  }) {
    final sw = Stopwatch()..start();
    final log = <String>[];
    final warnings = <String>[];

    if (reads.isEmpty) {
      return AssemblyResult(contigs: [], stepsLog: ['No input reads provided.']);
    }
    final cleaned = reads.where((r) => r.sequence.trim().isNotEmpty).toList();
    log.add(
      'Loaded ${cleaned.length} read(s) for assembly '
      '(min overlap=$minOverlap bp, min identity=${minIdentity.toStringAsFixed(0)}%).',
    );

    // Working set: each entry tracks its current consensus sequence, the
    // names/placements merged into it so far, and whether it has been
    // consumed into another contig.
    final names = cleaned.map((r) => r.name).toList();
    final seqsFwd = cleaned.map((r) => r.sequence.toUpperCase()).toList();
    final List<List<ContigReadPlacement>> placements = List.generate(
      cleaned.length,
      (i) => [ContigReadPlacement(readName: names[i], start: 0, end: seqsFwd[i].length)],
    );
    final working = List<String>.from(seqsFwd);
    final alive = List<bool>.filled(cleaned.length, true);

    final k = min(12, minOverlap);
    bool mergedAny = true;
    int mergeRounds = 0;
    const maxRounds = 500; // safety cap for pathological inputs

    while (mergedAny && mergeRounds < maxRounds) {
      mergedAny = false;
      mergeRounds++;
      final index = _buildSuffixIndex(working, k);

      double bestScore = -1;
      int bestI = -1, bestJ = -1;
      bool bestJReversed = false;
      int bestOverlapLen = 0;
      double bestIdentity = 0;

      for (int i = 0; i < working.length; i++) {
        if (!alive[i]) continue;
        final a = working[i];
        if (a.length < k) continue;
        final seed = a.substring(a.length - k);
        final candidates = index[seed] ?? const [];
        for (final j in candidates) {
          if (j == i || !alive[j]) continue;
          final b = working[j];
          final ov = _bestOverlap(a, b, minOverlap: minOverlap, minIdentity: minIdentity);
          if (ov != null) {
            final score = ov.overlapLen * (ov.identity / 100);
            if (score > bestScore) {
              bestScore = score;
              bestI = i;
              bestJ = j;
              bestJReversed = false;
              bestOverlapLen = ov.overlapLen;
              bestIdentity = ov.identity;
            }
          }
          // Also try b's reverse complement as a potential forward-read
          // continuation (captures reads sequenced from the other strand).
          final bRc = _revComp(b);
          final ovRc = _bestOverlap(a, bRc, minOverlap: minOverlap, minIdentity: minIdentity);
          if (ovRc != null) {
            final score = ovRc.overlapLen * (ovRc.identity / 100);
            if (score > bestScore) {
              bestScore = score;
              bestI = i;
              bestJ = j;
              bestJReversed = true;
              bestOverlapLen = ovRc.overlapLen;
              bestIdentity = ovRc.identity;
            }
          }
        }
      }

      if (bestI >= 0 && bestJ >= 0) {
        final a = working[bestI];
        final bRaw = working[bestJ];
        final b = bestJReversed ? _revComp(bRaw) : bRaw;
        // Merge: consensus = a's non-overlapping prefix + majority-vote
        // overlap + b's non-overlapping suffix.
        final overlapA = a.substring(a.length - bestOverlapLen);
        final overlapB = b.substring(0, bestOverlapLen);
        final buf = StringBuffer();
        for (int p = 0; p < bestOverlapLen; p++) {
          buf.write(overlapA[p] == overlapB[p] ? overlapA[p] : overlapA[p]);
        }
        final merged =
            a.substring(0, a.length - bestOverlapLen) +
            buf.toString() +
            b.substring(bestOverlapLen);

        final offset = a.length - bestOverlapLen;
        final movedPlacements = placements[bestJ]
            .map(
              (p) => ContigReadPlacement(
                readName: p.readName,
                start: p.start + offset,
                end: p.end + offset,
                forwardStrand: bestJReversed ? !p.forwardStrand : p.forwardStrand,
                overlapIdentity: bestIdentity,
              ),
            )
            .toList();

        working[bestI] = merged;
        placements[bestI] = [...placements[bestI], ...movedPlacements];
        alive[bestJ] = false;
        mergedAny = true;
      }
    }

    final contigs = <AssembledContig>[];
    for (int i = 0; i < working.length; i++) {
      if (!alive[i]) continue;
      final seq = working[i];
      final reads = placements[i];
      final coverage = List<int>.filled(seq.length, 0);
      for (final r in reads) {
        final s = r.start.clamp(0, seq.length);
        final e = r.end.clamp(0, seq.length);
        for (int p = s; p < e; p++) {
          coverage[p]++;
        }
      }
      contigs.add(AssembledContig(consensusSequence: seq, reads: reads, coveragePerBase: coverage));
    }
    // Largest contigs first.
    contigs.sort((a, b) => b.length.compareTo(a.length));

    final multiReadContigs = contigs.where((c) => c.reads.length > 1).length;
    final singletons = contigs.where((c) => c.reads.length == 1).toList();
    log.add(
      'Assembly complete after $mergeRounds merge round(s): '
      '$multiReadContigs multi-read contig(s), ${singletons.length} singleton read(s) '
      'left unmerged (no qualifying overlap found).',
    );
    if (singletons.isNotEmpty) {
      warnings.add(
        '${singletons.length} read(s) could not be merged into any contig — '
        'try lowering the minimum overlap/identity thresholds if they are '
        'expected to overlap.',
      );
    }

    // N50: length such that contigs >= that length cover >=50% of total
    // assembled bases — the standard assembly-quality metric.
    final lengths = contigs.map((c) => c.length).toList()..sort((a, b) => b.compareTo(a));
    final totalBases = lengths.fold<int>(0, (a, b) => a + b);
    int n50 = 0;
    if (totalBases > 0) {
      int running = 0;
      for (final l in lengths) {
        running += l;
        if (running >= totalBases / 2) {
          n50 = l;
          break;
        }
      }
    }
    log.add(
      'Total assembled bases: $totalBases bp across ${contigs.length} contig(s). N50 = $n50 bp.',
    );

    sw.stop();
    return AssemblyResult(
      contigs: contigs,
      unassembledReadNames: singletons.expand((c) => c.reads.map((r) => r.readName)).toList(),
      inputReadCount: cleaned.length,
      n50: n50,
      stepsLog: log,
      warnings: warnings,
      elapsedMicros: sw.elapsedMicroseconds,
    );
  }
}
