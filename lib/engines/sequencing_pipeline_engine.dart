import 'dart:typed_data';
import '../models/bio_sequence.dart';
import '../models/analysis_models.dart';
import 'sequence_engine.dart';
import 'alignment_engine.dart';
import 'abif_parser.dart';

/// Recognizes raw sequencer output (Illumina, Oxford Nanopore, PacBio,
/// Sanger) and runs a simplified, platform-appropriate processing pipeline
/// (demultiplexing, adapter/quality trimming, consensus building) to reach
/// a clean FASTA/FASTQ result.
///
/// IMPORTANT HONESTY NOTE: this operates on already-basecalled data
/// (FASTQ text for Illumina/ONT/PacBio, or the PBAS/PCON tags already
/// written by the instrument's own basecaller for Sanger .ab1 files).
/// True signal-level basecalling from raw nanopore squiggles or capillary
/// fluorescence traces requires specialized signal-processing/ML models
/// that are out of scope for an offline app — this pipeline reproduces the
/// downstream QC/demultiplexing/trimming/consensus steps that normally
/// follow basecalling.
class SequencingPipelineEngine {
  // ---------------- Platform detection ----------------
  static SequencingPlatform detectPlatform({
    required String fileName,
    Uint8List? bytes,
    String? textPreview,
  }) {
    final lower = fileName.toLowerCase();
    if (bytes != null && AbifParser.looksLikeAbif(bytes)) {
      return SequencingPlatform.sanger;
    }
    if (lower.endsWith('.ab1') || lower.endsWith('.scf')) {
      return SequencingPlatform.sanger;
    }
    if (textPreview != null && textPreview.trim().isNotEmpty) {
      final sample = textPreview.split(RegExp(r'\r?\n')).take(8).join('\n');
      // Illumina Casava 1.8+ header:
      // @<instrument>:<run>:<flowcell>:<lane>:<tile>:<x>:<y> <read>:<filtered>:<control>:<index>
      final illuminaHeader = RegExp(
        r'^@\S+:\d+:\S+:\d+:\d+:\d+:\d+\s+\d:[YN]:\d+:',
      );
      if (illuminaHeader.hasMatch(sample)) return SequencingPlatform.illumina;
      // ONT (MinKNOW/Guppy/Dorado) header contains runid=, ch=, start_time=
      if (sample.contains('runid=') &&
          (sample.contains(' ch=') || sample.contains('read='))) {
        return SequencingPlatform.nanopore;
      }
      // PacBio subread/CCS naming: <movie>/<zmw>/<start>_<end> or .../ccs
      final pacbioHeader = RegExp(r'[@>]\S+/\d+/(\d+_\d+|ccs)\b');
      if (pacbioHeader.hasMatch(sample)) return SequencingPlatform.pacbio;
      // Generic fallback: any FASTQ we can't fingerprint -> treat as
      // Illumina-style short reads (most common default).
      if (sample.trimLeft().startsWith('@')) return SequencingPlatform.illumina;
      if (sample.trimLeft().startsWith('>')) return SequencingPlatform.unknown;
    }
    return SequencingPlatform.unknown;
  }

  // ---------------- Shared helpers ----------------
  static int _hamming(String a, String b) {
    int d = 0;
    final n = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < n; i++) {
      if (a[i] != b[i]) d++;
    }
    return d + (a.length - b.length).abs();
  }

  /// Trimmomatic-style SLIDINGWINDOW quality trim: scans from the 5' end
  /// and cuts the read once the mean quality within [window] bases drops
  /// below [threshold].
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

  /// Mott's modified trimming algorithm (maximum-scoring subarray of
  /// (quality - threshold)) — the classic approach used to trim noisy
  /// 5'/3' ends of Sanger reads.
  static List<int> _mottTrim(List<int> quality, int threshold) {
    int maxSum = 0, curSum = 0, start = 0, bestStart = 0, bestEnd = 0;
    for (int i = 0; i < quality.length; i++) {
      curSum += quality[i] - threshold;
      if (curSum < 0) {
        curSum = 0;
        start = i + 1;
      }
      if (curSum > maxSum) {
        maxSum = curSum;
        bestStart = start;
        bestEnd = i + 1;
      }
    }
    if (maxSum == 0) return [0, quality.length];
    return [bestStart, bestEnd];
  }

  // ---------------- Illumina: demultiplex + adapter/quality trim ----------------
  static SequencingPipelineResult processIllumina(
    String fastqContent, {
    List<DemuxSample> barcodes = const [],
    int qualityThreshold = 20,
    int slidingWindow = 4,
    String adapter = 'AGATCGGAAGAGC',
    int minFinalLength = 20,
  }) {
    final log = <String>[];
    final warnings = <String>[];
    final reads = SequenceEngine.parseFastq(fastqContent);
    log.add('Detected Illumina-style FASTQ. Parsed ${reads.length} raw reads.');

    List<BioSequence> demuxed;
    if (barcodes.isNotEmpty) {
      log.add(
        'Demultiplexing against ${barcodes.length} sample barcode(s) '
        '(in-line prefix match, Hamming distance <= 1).',
      );
      int assigned = 0, unassigned = 0;
      final out = <BioSequence>[];
      for (final r in reads) {
        String? matchedSample;
        int barcodeLen = 0;
        for (final b in barcodes) {
          if (r.sequence.length >= b.barcode.length) {
            final prefix = r.sequence.substring(0, b.barcode.length);
            if (_hamming(prefix, b.barcode) <= 1) {
              matchedSample = b.name;
              barcodeLen = b.barcode.length;
              break;
            }
          }
        }
        if (matchedSample != null) {
          assigned++;
          final newSeq = r.sequence.substring(barcodeLen);
          final newQual = r.qualityScores?.sublist(barcodeLen);
          out.add(
            r.copyWith(
              name: '${matchedSample}_${r.name}',
              sequence: newSeq,
              qualityScores: newQual,
              tags: [...r.tags, 'sample:$matchedSample'],
            ),
          );
        } else {
          unassigned++;
        }
      }
      demuxed = out;
      log.add(
        'Demultiplexing result: $assigned reads assigned to samples, '
        '$unassigned unassigned (discarded).',
      );
      if (unassigned > 0) {
        warnings.add(
          '$unassigned reads did not match any provided barcode and were discarded.',
        );
      }
    } else {
      demuxed = reads;
      log.add(
        'No barcode sheet provided — skipping demultiplexing (treating as single sample).',
      );
    }

    int adapterTrimmed = 0;
    final probe = adapter.length > 12 ? adapter.substring(0, 12) : adapter;
    final afterAdapter = demuxed.map((r) {
      final idx = r.sequence.indexOf(probe);
      if (idx >= 0) {
        adapterTrimmed++;
        final newQual = r.qualityScores?.sublist(0, idx);
        return r.copyWith(
          sequence: r.sequence.substring(0, idx),
          qualityScores: newQual,
        );
      }
      return r;
    }).toList();
    log.add(
      'Adapter trimming (search for "$probe..."): $adapterTrimmed read(s) trimmed.',
    );

    int qualityTrimmedBases = 0;
    final afterQuality = <BioSequence>[];
    for (final r in afterAdapter) {
      final q = r.qualityScores;
      if (q == null || q.isEmpty) {
        afterQuality.add(r);
        continue;
      }
      final trimEnd = _slidingWindowTrim(q, slidingWindow, qualityThreshold);
      if (trimEnd < r.sequence.length) {
        qualityTrimmedBases += r.sequence.length - trimEnd;
        afterQuality.add(
          r.copyWith(
            sequence: r.sequence.substring(0, trimEnd),
            qualityScores: q.sublist(0, trimEnd),
          ),
        );
      } else {
        afterQuality.add(r);
      }
    }
    log.add(
      'Quality trimming (sliding window=$slidingWindow bp, Q<$qualityThreshold): '
      'removed $qualityTrimmedBases low-quality base(s) total.',
    );

    final finalReads = afterQuality
        .where((r) => r.sequence.length >= minFinalLength)
        .map((r) => r.copyWith(source: 'sequencing:illumina'))
        .toList();
    if (finalReads.length < afterQuality.length) {
      warnings.add(
        '${afterQuality.length - finalReads.length} read(s) discarded '
        '(final length below $minFinalLength bp after trimming).',
      );
    }
    log.add(
      'Pipeline complete: ${finalReads.length} clean read(s) ready for FASTA/FASTQ export.',
    );

    return SequencingPipelineResult(
      platform: SequencingPlatform.illumina,
      stepsLog: log,
      outputSequences: finalReads,
      warnings: warnings,
      inputReadCount: reads.length,
    );
  }

  // ---------------- Oxford Nanopore: quality/length filter + trim ----------------
  static SequencingPipelineResult processNanopore(
    String fastqContent, {
    int minLength = 200,
    double minMeanQuality = 9,
    String adapter = 'AATGTACTTCGTTCAGTTACGTATTGCT',
  }) {
    final log = <String>[];
    final warnings = <String>[];
    final reads = SequenceEngine.parseFastq(fastqContent);
    log.add(
      'Detected Oxford Nanopore-style FASTQ. Parsed ${reads.length} raw reads.',
    );

    int lengthFiltered = 0, qualityFiltered = 0;
    final passed = <BioSequence>[];
    for (final r in reads) {
      if (r.sequence.length < minLength) {
        lengthFiltered++;
        continue;
      }
      final q = r.qualityScores;
      final meanQ = (q == null || q.isEmpty)
          ? 100.0 // if no quality info, don't filter on it
          : q.reduce((a, b) => a + b) / q.length;
      if (meanQ < minMeanQuality) {
        qualityFiltered++;
        continue;
      }
      passed.add(r);
    }
    log.add(
      'Length filter (< $minLength bp): removed $lengthFiltered read(s).',
    );
    log.add(
      'Quality filter (mean Q < $minMeanQuality): removed $qualityFiltered read(s).',
    );

    final probe = adapter.length > 14 ? adapter.substring(0, 14) : adapter;
    int trimmedEnds = 0;
    final trimmed = passed.map((r) {
      var seq = r.sequence;
      var qual = r.qualityScores;
      final idx = seq.indexOf(probe);
      if (idx >= 0) {
        trimmedEnds++;
        seq = seq.substring(0, idx);
        qual = qual?.sublist(0, idx);
      }
      return r.copyWith(
        sequence: seq,
        qualityScores: qual,
        source: 'sequencing:nanopore',
      );
    }).toList();
    log.add('Adapter trimming: $trimmedEnds read(s) trimmed at adapter site.');

    if (trimmed.isEmpty) {
      warnings.add(
        'No reads passed the Nanopore QC filters — check the raw file or relax thresholds.',
      );
    }
    log.add(
      'Pipeline complete: ${trimmed.length} filtered read(s) ready for FASTA/FASTQ export.',
    );

    return SequencingPipelineResult(
      platform: SequencingPlatform.nanopore,
      stepsLog: log,
      outputSequences: trimmed,
      warnings: warnings,
      inputReadCount: reads.length,
    );
  }

  // ---------------- PacBio: group subreads by ZMW + build CCS consensus ----------------
  static SequencingPipelineResult processPacBio(String content) {
    final log = <String>[];
    final warnings = <String>[];
    final reads = SequenceEngine.parseAuto(content, source: 'pacbio_raw');
    log.add(
      'Detected PacBio-style read naming. Parsed ${reads.length} raw subreads.',
    );

    final Map<String, List<BioSequence>> groups = {};
    for (final r in reads) {
      final parts = r.name.split('/');
      final key = parts.length >= 2 ? '${parts[0]}/${parts[1]}' : r.name;
      groups.putIfAbsent(key, () => []).add(r);
    }
    log.add(
      'Grouped subreads into ${groups.length} ZMW molecule(s) by movie/ZMW ID.',
    );

    final ccsReads = <BioSequence>[];
    int singlePass = 0;
    for (final entry in groups.entries) {
      final subs = entry.value;
      if (subs.length == 1) {
        singlePass++;
        ccsReads.add(
          subs.first.copyWith(
            name: '${entry.key}_ccs',
            source: 'pacbio_ccs',
            tags: [...subs.first.tags, 'single_pass'],
          ),
        );
        continue;
      }
      final names = subs.map((s) => s.name).toList();
      final seqs = subs.map((s) => s.sequence).toList();
      String consensus;
      try {
        final msa = AlignmentEngine.multipleAlign(names, seqs);
        consensus = msa.consensusSequence.replaceAll('-', '');
      } catch (_) {
        // Fallback: use the longest subread if alignment fails
        seqs.sort((a, b) => b.length.compareTo(a.length));
        consensus = seqs.first;
      }
      ccsReads.add(
        BioSequence(
          name: '${entry.key}_ccs',
          type: SequenceEngine.detectType(consensus),
          sequence: consensus,
          source: 'pacbio_ccs',
          tags: ['${subs.length}_passes'],
        ),
      );
    }
    log.add(
      'Generated ${ccsReads.length} circular consensus (HiFi-like) read(s) '
      'via multi-subread alignment consensus.',
    );
    if (singlePass > 0) {
      warnings.add(
        '$singlePass ZMW(s) had only 1 subread pass — lower-confidence consensus (no error correction possible).',
      );
    }

    return SequencingPipelineResult(
      platform: SequencingPlatform.pacbio,
      stepsLog: log,
      outputSequences: ccsReads,
      warnings: warnings,
      inputReadCount: reads.length,
    );
  }

  // ---------------- Sanger: parse ABIF trace + Mott quality trim ----------------
  static SequencingPipelineResult processSanger(
    Uint8List bytes, {
    String fileName = 'sanger_trace',
    int qualityThreshold = 20,
  }) {
    final log = <String>[];
    final warnings = <String>[];
    final rec = AbifParser.parse(bytes);
    if (rec == null) {
      return SequencingPipelineResult(
        platform: SequencingPlatform.sanger,
        stepsLog: [
          'Failed to parse ABIF (.ab1) file — the file may be corrupted, '
              'encrypted, or use an unsupported trace format variant.',
        ],
        outputSequences: [],
        warnings: ['ABIF parsing failed.'],
      );
    }
    log.add(
      'Parsed ABIF trace file: ${rec.bases.length} called bases extracted '
      '(basecalling already performed by the sequencer\'s own software; '
      'this app reads the resulting PBAS/PCON tags, not the raw fluorescence trace).',
    );

    final cleanBases = rec.bases.toUpperCase();
    String finalSeq;
    List<int>? finalQual;

    if (rec.quality.isNotEmpty && rec.quality.length == cleanBases.length) {
      final window = _mottTrim(rec.quality, qualityThreshold);
      final start = window[0];
      final end = window[1];
      finalSeq = SequenceEngine.sanitize(cleanBases.substring(start, end));
      final trimmedQual = rec.quality.sublist(start, end);
      finalQual = trimmedQual.length == finalSeq.length ? trimmedQual : null;
      log.add(
        'Quality-based trimming (Mott algorithm, threshold Q$qualityThreshold): '
        'kept bases $start-$end of ${cleanBases.length} (removed noisy 5\'/3\' ends).',
      );
      if (start == 0 && end == cleanBases.length) {
        warnings.add(
          'No clear high-quality region detected — full-length read kept as-is; manual QC recommended.',
        );
      }
    } else {
      finalSeq = SequenceEngine.sanitize(cleanBases);
      warnings.add(
        'No usable per-base quality (PCON) values found — trace exported without quality-based trimming.',
      );
      log.add('No quality trimming applied (missing PCON tag).');
    }

    final baseName = fileName.replaceAll(
      RegExp(r'\.(ab1|scf)$', caseSensitive: false),
      '',
    );
    final out = BioSequence(
      name: baseName.isEmpty ? 'sanger_read' : baseName,
      type: SequenceEngine.detectType(finalSeq),
      sequence: finalSeq,
      qualityScores: finalQual,
      source: 'sequencing:sanger',
    );
    log.add(
      'Pipeline complete: 1 high-quality consensus read ready (${finalSeq.length} bp).',
    );

    return SequencingPipelineResult(
      platform: SequencingPlatform.sanger,
      stepsLog: log,
      outputSequences: [out],
      warnings: warnings,
      inputReadCount: 1,
    );
  }
}
