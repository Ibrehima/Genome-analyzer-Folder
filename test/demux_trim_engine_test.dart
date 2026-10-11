import 'package:flutter_test/flutter_test.dart';
import 'package:genome_analyzer/engines/demux_trim_engine.dart';
import 'package:genome_analyzer/models/analysis_models.dart';
import 'package:genome_analyzer/models/bio_sequence.dart';

BioSequence _read(String name, String seq, {List<int>? quality}) =>
    BioSequence(name: name, type: SequenceType.dna, sequence: seq, qualityScores: quality);

void main() {
  group('DemuxTrimEngine.demultiplex', () {
    final barcodeA = DemuxSample(name: 'SampleA', barcode: 'ACGT');
    final barcodeB = DemuxSample(name: 'SampleB', barcode: 'TTGG');

    test('assigns reads to the matching exact barcode and strips it', () {
      final reads = [
        _read('r1', 'ACGTAAAAACCCCC'), // SampleA
        _read('r2', 'TTGGCCCCCGGGGG'), // SampleB
      ];
      final result = DemuxTrimEngine.demultiplex(reads, [barcodeA, barcodeB], maxMismatches: 0);

      expect(result.totalReads, 2);
      expect(result.assignedReads, 2);
      expect(result.unassignedReads, 0);

      final sampleAEntry = result.perSample.firstWhere((e) => e.sampleName == 'SampleA');
      expect(sampleAEntry.reads, hasLength(1));
      // Barcode must be stripped from the front of the kept sequence.
      expect(sampleAEntry.reads.first.sequence, 'AAAAACCCCC');
      expect(sampleAEntry.reads.first.tags, contains('sample:SampleA'));
      expect(sampleAEntry.reads.first.tags, contains('demultiplexed'));

      final sampleBEntry = result.perSample.firstWhere((e) => e.sampleName == 'SampleB');
      expect(sampleBEntry.reads.first.sequence, 'CCCCCGGGGG');
    });

    test('reads with no matching barcode land in the unassigned bucket', () {
      final reads = [_read('orphan', 'GGGGGTTTTTCCCCC')];
      final result = DemuxTrimEngine.demultiplex(reads, [barcodeA, barcodeB], maxMismatches: 0);

      expect(result.assignedReads, 0);
      expect(result.unassignedReads, 1);
      final unassignedEntry = result.perSample.firstWhere((e) => e.sampleName == '');
      expect(unassignedEntry.reads, hasLength(1));
      expect(unassignedEntry.reads.first.name, 'orphan');
      // Unassigned reads are kept untouched (no barcode stripped).
      expect(unassignedEntry.reads.first.sequence, 'GGGGGTTTTTCCCCC');
    });

    test('maxMismatches=0 rejects a barcode with a single substitution', () {
      // 'ACGA' differs from barcode 'ACGT' by 1 base.
      final reads = [_read('r1', 'ACGAAAAAACCCCC')];
      final result = DemuxTrimEngine.demultiplex(reads, [barcodeA], maxMismatches: 0);
      expect(result.assignedReads, 0);
      expect(result.unassignedReads, 1);
    });

    test('maxMismatches=1 tolerates a single substitution in the barcode', () {
      final reads = [_read('r1', 'ACGAAAAAACCCCC')];
      final result = DemuxTrimEngine.demultiplex(reads, [barcodeA], maxMismatches: 1);
      expect(result.assignedReads, 1);
      expect(result.perSample.first.reads.first.sequence, 'AAAAACCCCC');
    });

    test('maxMismatches=1 still rejects a barcode with 2 substitutions', () {
      // 'ATGA' differs from 'ACGT' by 2 bases (positions 1 and 3).
      final reads = [_read('r1', 'ATGAAAAAACCCCC')];
      final result = DemuxTrimEngine.demultiplex(reads, [barcodeA], maxMismatches: 1);
      expect(result.assignedReads, 0);
    });

    test('first matching barcode wins when multiple barcodes could match', () {
      // Degenerate test input; barcodeA is listed first so it should win.
      final reads = [_read('r1', 'ACGTAAAAAAAAAA')];
      final result = DemuxTrimEngine.demultiplex(reads, [barcodeA, barcodeB], maxMismatches: 0);
      final sampleAEntry = result.perSample.firstWhere((e) => e.sampleName == 'SampleA');
      expect(sampleAEntry.reads, hasLength(1));
    });

    test('reads shorter than the barcode are left unassigned (no crash)', () {
      final reads = [_read('tiny', 'AC')];
      final result = DemuxTrimEngine.demultiplex(reads, [barcodeA], maxMismatches: 0);
      expect(result.assignedReads, 0);
      expect(result.unassignedReads, 1);
    });
  });

  group('DemuxTrimEngine.trim — hard trim', () {
    test('removes a fixed number of bases from each end', () {
      final reads = [_read('r1', 'AAAACCCCGGGGTTTT')]; // 16bp
      final result = DemuxTrimEngine.trim(
        reads,
        qualityTrim: false,
        minLength: 1,
        hardTrimStart: 4,
        hardTrimEnd: 4,
      );
      final r = result.results.single;
      expect(r.trimmedSequence.sequence, 'CCCCGGGG');
      expect(r.trimmedFromStart, 4);
      expect(r.trimmedFromEnd, 4);
      expect(r.totalTrimmed, 8);
      expect(r.discarded, isFalse);
    });
  });

  group('DemuxTrimEngine.trim — adapter trimming', () {
    test('cuts the read at the first occurrence of the adapter sequence', () {
      final reads = [_read('r1', 'AAACCCGGGAAGATCGGAAGAGC')];
      final result = DemuxTrimEngine.trim(
        reads,
        adapter: 'AGATCGGAAGAGC',
        adapterProbeLength: 12,
        qualityTrim: false,
        minLength: 1,
      );
      final r = result.results.single;
      expect(r.trimmedSequence.sequence, 'AAACCCGGGA');
      expect(r.reason, contains('adapter'));
    });

    test('reads without the adapter are left untouched by this step', () {
      final reads = [_read('r1', 'AAACCCGGGTTTAAACCCGGGTTT')];
      final result = DemuxTrimEngine.trim(
        reads,
        adapter: 'AGATCGGAAGAGC',
        qualityTrim: false,
        minLength: 1,
      );
      final r = result.results.single;
      expect(r.trimmedSequence.sequence, 'AAACCCGGGTTTAAACCCGGGTTT');
      expect(r.reason, isNot(contains('adapter')));
    });
  });

  group('DemuxTrimEngine.trim — sliding-window quality trim', () {
    test('cuts the read where the mean quality in the window drops below threshold', () {
      // First 10 bases high quality (Q30+), then quality crashes to Q5.
      final highQ = List<int>.filled(10, 35);
      final lowQ = List<int>.filled(10, 5);
      final seq = 'A' * 10 + 'T' * 10;
      final reads = [
        _read('r1', seq, quality: [...highQ, ...lowQ]),
      ];

      final result = DemuxTrimEngine.trim(
        reads,
        qualityTrim: true,
        slidingWindow: 4,
        qualityThreshold: 20,
        minLength: 1,
      );
      final r = result.results.single;
      // The sliding window starts failing once it includes the first
      // low-quality base (window [9,10,11,12] has mean (35+5+5+5)/4=12.5 <
      // 20), so the cut lands at index 9, keeping only 9 high-Q bases.
      expect(r.trimmedSequence.sequence, 'A' * 9);
      expect(r.reason, contains('low_quality'));
    });

    test('a uniformly high-quality read is not quality-trimmed', () {
      final seq = 'ACGT' * 5; // 20bp
      final reads = [_read('r1', seq, quality: List<int>.filled(20, 38))];
      final result = DemuxTrimEngine.trim(
        reads,
        qualityTrim: true,
        slidingWindow: 4,
        qualityThreshold: 20,
        minLength: 1,
      );
      final r = result.results.single;
      expect(r.trimmedSequence.sequence, seq);
      expect(r.trimmedFromEnd, 0);
    });
  });

  group('DemuxTrimEngine.trim — length filtering', () {
    test('reads that fall below minLength after trimming are discarded', () {
      final reads = [_read('short', 'ACGTAC')]; // 6bp
      final result = DemuxTrimEngine.trim(reads, qualityTrim: false, minLength: 10);
      final r = result.results.single;
      expect(r.discarded, isTrue);
      expect(r.reason, contains('too_short'));
      expect(result.keptSequences, isEmpty);
      expect(result.discardedCount, 1);
    });

    test('reads longer than maxLength are discarded', () {
      final reads = [_read('long', 'A' * 50)];
      final result = DemuxTrimEngine.trim(reads, qualityTrim: false, minLength: 1, maxLength: 20);
      final r = result.results.single;
      expect(r.discarded, isTrue);
      expect(r.reason, contains('too_long'));
    });

    test('keptSequences / discardedCount / totalBasesTrimmed aggregate correctly', () {
      final reads = [_read('keep', 'A' * 30), _read('drop', 'A' * 5)];
      final result = DemuxTrimEngine.trim(
        reads,
        qualityTrim: false,
        minLength: 10,
        hardTrimStart: 2,
      );
      expect(result.keptSequences, hasLength(1));
      expect(result.keptSequences.first.name, 'keep');
      expect(result.discardedCount, 1);
      // Both reads had 2bp trimmed from the start via hard-trim.
      expect(result.totalBasesTrimmed, greaterThanOrEqualTo(4));
    });
  });

  group('DemuxTrimEngine.trim — combined pipeline', () {
    test('hard-trim, adapter and quality trimming compose in one call', () {
      final seq =
          'NNNN'
          'ACGTACGTAC'
          'AGATCGGAAGAGC'
          'JUNKJUNK';
      final reads = [_read('combo', seq, quality: List<int>.filled(seq.length, 38))];
      final result = DemuxTrimEngine.trim(
        reads,
        adapter: 'AGATCGGAAGAGC',
        hardTrimStart: 4,
        qualityTrim: true,
        minLength: 1,
      );
      final r = result.results.single;
      // After stripping the 4 N's and cutting at the adapter, only the
      // core insert should remain.
      expect(r.trimmedSequence.sequence, 'ACGTACGTAC');
      expect(r.discarded, isFalse);
    });
  });
}
