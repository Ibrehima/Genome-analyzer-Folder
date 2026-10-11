import '../models/bio_sequence.dart';
import '../models/analysis_models.dart';

/// Standalone demultiplexing & trimming engine — unlike
/// [SequencingPipelineEngine] (which is bundled into one raw-file pipeline
/// per platform), these utilities work on any list of [BioSequence] already
/// in the library/project, so they can be used as independent modules: run
/// demultiplexing on its own, or trimming on its own, mixing and matching
/// steps and sequence sources freely.
class DemuxTrimEngine {
  static int _hamming(String a, String b) {
    int d = 0;
    final n = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < n; i++) {
      if (a[i] != b[i]) d++;
    }
    return d + (a.length - b.length).abs();
  }

  // ---------------- Demultiplexing ----------------

  /// Splits [reads] into per-sample buckets using 5' in-line barcode
  /// matching (Hamming distance <= [maxMismatches]). Barcodes are stripped
  /// from the kept sequence. Reads matching no barcode go to the
  /// 'unassigned' bucket (sampleName: '').
  static DemuxBatchResult demultiplex(
    List<BioSequence> reads,
    List<DemuxSample> barcodes, {
    int maxMismatches = 1,
  }) {
    final log = <String>[];
    log.add(
      'Demultiplexing ${reads.length} read(s) against ${barcodes.length} '
      'barcode(s) (5\' in-line match, Hamming distance <= $maxMismatches).',
    );

    final Map<String, List<BioSequence>> buckets = {for (final b in barcodes) b.name: []};
    final unassigned = <BioSequence>[];
    int assigned = 0;

    for (final r in reads) {
      String? matchedSample;
      int barcodeLen = 0;
      for (final b in barcodes) {
        if (r.sequence.length >= b.barcode.length) {
          final prefix = r.sequence.substring(0, b.barcode.length);
          if (_hamming(prefix, b.barcode) <= maxMismatches) {
            matchedSample = b.name;
            barcodeLen = b.barcode.length;
            break;
          }
        }
      }
      if (matchedSample != null) {
        assigned++;
        final newSeq = r.sequence.substring(barcodeLen);
        final newQual = r.qualityScores?.sublist(barcodeLen.clamp(0, r.qualityScores!.length));
        buckets[matchedSample]!.add(
          r.copyWith(
            name: '${matchedSample}_${r.name}',
            sequence: newSeq,
            qualityScores: newQual,
            tags: [...r.tags, 'sample:$matchedSample', 'demultiplexed'],
          ),
        );
      } else {
        unassigned.add(r);
      }
    }

    log.add(
      'Result: $assigned read(s) assigned across ${barcodes.length} sample(s), '
      '${unassigned.length} unassigned.',
    );

    final perSample = <DemuxResultEntry>[
      for (final b in barcodes) DemuxResultEntry(sampleName: b.name, reads: buckets[b.name]!),
      DemuxResultEntry(sampleName: '', reads: unassigned),
    ];

    return DemuxBatchResult(
      perSample: perSample,
      totalReads: reads.length,
      assignedReads: assigned,
      stepsLog: log,
    );
  }

  // ---------------- Trimming ----------------

  /// Trimmomatic-style SLIDINGWINDOW quality trim from the 5' end: cuts the
  /// read once the mean quality within [window] bases drops below
  /// [threshold]. Returns the index to keep up to (exclusive).
  static int _slidingWindowTrim(List<int> quality, int window, int threshold) {
    if (quality.isEmpty) return 0;
    if (quality.length < window) {
      final mean = quality.reduce((a, b) => a + b) / quality.length;
      return mean >= threshold ? quality.length : 0;
    }
    for (int i = 0; i <= quality.length - window; i++) {
      final slice = quality.sublist(i, i + window);
      final mean = slice.reduce((a, b) => a + b) / window;
      if (mean < threshold) return i;
    }
    return quality.length;
  }

  /// Runs adapter trimming (simple substring search for the adapter's
  /// first [adapterProbeLength] bases), then — if quality scores are
  /// present — sliding-window quality trimming, then a minimum/maximum
  /// length filter. Any combination of steps can be disabled by passing
  /// null/empty for that parameter.
  static TrimBatchResult trim(
    List<BioSequence> reads, {
    String? adapter,
    int adapterProbeLength = 12,
    bool qualityTrim = true,
    int slidingWindow = 4,
    int qualityThreshold = 20,
    int minLength = 20,
    int? maxLength,
    int hardTrimStart = 0,
    int hardTrimEnd = 0,
  }) {
    final log = <String>[];
    log.add('Trimming ${reads.length} read(s).');
    if (hardTrimStart > 0 || hardTrimEnd > 0) {
      log.add(
        'Hard-trim: removing $hardTrimStart bp from the 5\' end and '
        '$hardTrimEnd bp from the 3\' end of every read.',
      );
    }
    if (adapter != null && adapter.trim().isNotEmpty) {
      final probe = adapter.length > adapterProbeLength
          ? adapter.substring(0, adapterProbeLength)
          : adapter;
      log.add('Adapter trimming: searching for "$probe...".');
    }
    if (qualityTrim) {
      log.add('Quality trimming: sliding window=$slidingWindow bp, threshold=Q$qualityThreshold.');
    }
    log.add(
      'Length filter: keep reads between $minLength'
      '${maxLength != null ? " and $maxLength" : "+"} bp after trimming.',
    );

    final results = <TrimResult>[];
    for (final r in reads) {
      var seq = r.sequence;
      var qual = r.qualityScores;
      final originalLength = seq.length;
      int trimmedStart = 0;
      int trimmedEnd = 0;
      String reason = '';

      // 1. Hard trim (fixed N bases off each end) — useful for known
      // primer/barcode remnants of a fixed length.
      if (hardTrimStart > 0 && seq.length > hardTrimStart) {
        seq = seq.substring(hardTrimStart);
        qual = qual != null && qual.length > hardTrimStart ? qual.sublist(hardTrimStart) : qual;
        trimmedStart += hardTrimStart;
      }
      if (hardTrimEnd > 0 && seq.length > hardTrimEnd) {
        seq = seq.substring(0, seq.length - hardTrimEnd);
        qual = qual != null && qual.length > hardTrimEnd
            ? qual.sublist(0, qual.length - hardTrimEnd)
            : qual;
        trimmedEnd += hardTrimEnd;
      }

      // 2. Adapter trim (3' search).
      if (adapter != null && adapter.trim().isNotEmpty) {
        final probe = adapter.length > adapterProbeLength
            ? adapter.substring(0, adapterProbeLength)
            : adapter;
        final idx = seq.indexOf(probe);
        if (idx >= 0) {
          trimmedEnd += seq.length - idx;
          seq = seq.substring(0, idx);
          qual = qual?.sublist(0, idx);
          reason = 'adapter';
        }
      }

      // 3. Quality trim (sliding window from the 5' end).
      if (qualityTrim && qual != null && qual.isNotEmpty) {
        final keepTo = _slidingWindowTrim(qual, slidingWindow, qualityThreshold);
        if (keepTo < seq.length) {
          trimmedEnd += seq.length - keepTo;
          seq = seq.substring(0, keepTo);
          qual = qual.sublist(0, keepTo);
          reason = reason.isEmpty ? 'low_quality' : '$reason+low_quality';
        }
      }

      final tooShort = seq.length < minLength;
      final tooLong = maxLength != null && seq.length > maxLength;
      final discarded = tooShort || tooLong;
      if (tooShort) reason = reason.isEmpty ? 'too_short' : '$reason+too_short';
      if (tooLong) reason = reason.isEmpty ? 'too_long' : '$reason+too_long';

      results.add(
        TrimResult(
          trimmedSequence: r.copyWith(
            sequence: seq,
            qualityScores: qual,
            tags: [...r.tags, 'trimmed'],
          ),
          originalLength: originalLength,
          trimmedFromStart: trimmedStart,
          trimmedFromEnd: trimmedEnd,
          discarded: discarded,
          reason: reason,
        ),
      );
    }

    final kept = results.where((r) => !r.discarded).length;
    log.add(
      'Trimming complete: $kept read(s) kept, '
      '${results.length - kept} discarded (below min / above max length).',
    );

    return TrimBatchResult(results: results, stepsLog: log);
  }
}
