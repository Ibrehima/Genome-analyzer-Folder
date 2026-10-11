import 'package:flutter_test/flutter_test.dart';
import 'package:genome_analyzer/engines/contig_assembly_engine.dart';
import 'package:genome_analyzer/engines/sequence_engine.dart';
import 'package:genome_analyzer/models/bio_sequence.dart';

BioSequence _read(String name, String seq) =>
    BioSequence(name: name, type: SequenceType.dna, sequence: seq);

void main() {
  group('ContigAssemblyEngine.assemble — edge cases', () {
    test('empty input returns an empty result with an explanatory log', () {
      final result = ContigAssemblyEngine.assemble([]);
      expect(result.contigs, isEmpty);
      expect(result.stepsLog, contains('No input reads provided.'));
      expect(result.inputReadCount, 0);
      expect(result.n50, 0);
      expect(result.totalAssembledBases, 0);
    });

    test('blank/whitespace-only reads are filtered out before assembly', () {
      final reads = [_read('blank', '   '), _read('real', 'AAACCCTTTGGG')];
      final result = ContigAssemblyEngine.assemble(reads, minOverlap: 5, minIdentity: 90);
      expect(result.inputReadCount, 1);
      expect(result.contigs, hasLength(1));
      expect(result.contigs.first.consensusSequence, 'AAACCCTTTGGG');
    });
  });

  group('ContigAssemblyEngine.assemble — forward-strand overlap merging', () {
    test('two reads with a clean 6bp suffix/prefix overlap merge into one contig', () {
      // suffix(A) = "TTTGGG" == prefix(B) = "TTTGGG" -> 100% identity overlap.
      final a = _read('readA', 'AAACCCTTTGGG');
      final b = _read('readB', 'TTTGGGAAACCC');
      final result = ContigAssemblyEngine.assemble([a, b], minOverlap: 5, minIdentity: 90);

      expect(result.contigs, hasLength(1));
      final contig = result.contigs.first;
      expect(contig.consensusSequence, 'AAACCCTTTGGGAAACCC');
      expect(contig.length, 18);
      expect(contig.reads, hasLength(2));
      expect(contig.reads.map((r) => r.readName), containsAll(['readA', 'readB']));
      expect(result.unassembledReadNames, isEmpty);
      expect(result.n50, 18);
      expect(result.totalAssembledBases, 18);
    });

    test('reads with no qualifying overlap remain separate singleton contigs', () {
      final a = _read('polyA', 'AAAAAAAAAA');
      final b = _read('polyC', 'CCCCCCCCCC');
      final result = ContigAssemblyEngine.assemble([a, b], minOverlap: 5, minIdentity: 90);

      expect(result.contigs, hasLength(2));
      expect(result.contigs.every((c) => c.reads.length == 1), isTrue);
      expect(result.unassembledReadNames, containsAll(['polyA', 'polyC']));
      // Equal-length singletons -> N50 equals that common length.
      expect(result.n50, 10);
    });

    test('raising the identity threshold rejects a near-match overlap', () {
      // suffix(A) "TTTGGG" vs prefix(F) "TTAGGG" -> 1 mismatch -> 83% identity.
      final a = _read('readA', 'AAACCCTTTGGG');
      final f = _read('readF', 'TTAGGGCCCCCC');
      final result = ContigAssemblyEngine.assemble([a, f], minOverlap: 5, minIdentity: 100);

      expect(result.contigs, hasLength(2));
      expect(result.unassembledReadNames, containsAll(['readA', 'readF']));
    });
  });

  group('ContigAssemblyEngine.assemble — reverse-complement overlap', () {
    test('merges when only the reverse complement of a read overlaps', () {
      final a = _read('readA', 'AAACCCTTTGGG');
      // readD is the reverse complement of "TTTGGGAAACCC" (which would
      // overlap readA directly) — the engine must try revComp(b) too.
      final revCompOfB = SequenceEngine.reverseComplement('TTTGGGAAACCC');
      final d = _read('readD', revCompOfB);

      final result = ContigAssemblyEngine.assemble([a, d], minOverlap: 5, minIdentity: 90);

      expect(result.contigs, hasLength(1));
      expect(result.contigs.first.consensusSequence, 'AAACCCTTTGGGAAACCC');
      expect(result.contigs.first.reads, hasLength(2));
    });
  });

  group('ContigAssemblyEngine.assemble — N50 / coverage metrics', () {
    test('N50 is computed correctly for a known set of contig lengths', () {
      // minOverlap larger than every read length guarantees zero merges,
      // so each read becomes its own singleton "contig" of known length.
      final reads = [_read('r10', 'A' * 10), _read('r20', 'C' * 20), _read('r30', 'G' * 30)];
      final result = ContigAssemblyEngine.assemble(reads, minOverlap: 100, minIdentity: 100);

      expect(result.contigs, hasLength(3));
      expect(result.totalAssembledBases, 60);
      // Sorted desc: [30, 20, 10], total=60, half=30 -> cumulative 30 >= 30 at the first (30bp) contig.
      expect(result.n50, 30);
    });

    test('coveragePerBase reflects the number of reads placed at each position', () {
      final a = _read('readA', 'AAACCCTTTGGG');
      final b = _read('readB', 'TTTGGGAAACCC');
      final result = ContigAssemblyEngine.assemble([a, b], minOverlap: 5, minIdentity: 90);
      final contig = result.contigs.first;

      expect(contig.coveragePerBase, hasLength(contig.length));
      // The 6bp overlap region (where both reads contribute) must have
      // coverage 2; the non-overlapping flanks have coverage 1.
      final maxCoverage = contig.coveragePerBase.reduce((a, b) => a > b ? a : b);
      expect(maxCoverage, 2);
      expect(contig.meanCoverage, greaterThan(1.0));
    });
  });
}
