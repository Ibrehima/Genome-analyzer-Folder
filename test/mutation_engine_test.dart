import 'package:flutter_test/flutter_test.dart';
import 'package:genome_analyzer/engines/mutation_engine.dart';
import 'package:genome_analyzer/models/analysis_models.dart';

void main() {
  group('MutationEngine.callFromAlignment — basic variant calling', () {
    test('identical aligned sequences produce zero mutations', () {
      final result = MutationEngine.callFromAlignment('ACGTACGT', 'ACGTACGT');
      expect(result.mutations, isEmpty);
      expect(result.snpCount, 0);
      expect(result.insertionCount, 0);
      expect(result.deletionCount, 0);
    });

    test('a single-base substitution is reported with correct ref coordinates', () {
      // Position 4 (0-based) differs: A -> G.
      final result = MutationEngine.callFromAlignment('ACGTACGT', 'ACGTGCGT');
      expect(result.mutations, hasLength(1));
      final m = result.mutations.single;
      expect(m.type, MutationType.substitution);
      expect(m.refStart, 4);
      expect(m.refEnd, 5);
      expect(m.refAllele, 'A');
      expect(m.altAllele, 'G');
      expect(m.notation, '5A>G'); // 1-based notation
      expect(result.snpCount, 1);
    });

    test('consecutive substitution columns are merged into one MNP-style block', () {
      // Positions 2-3 both differ: GT -> AA.
      final result = MutationEngine.callFromAlignment('ACGTACGT', 'ACAAACGT');
      expect(result.mutations, hasLength(1));
      final m = result.mutations.single;
      expect(m.type, MutationType.substitution);
      expect(m.refAllele, 'GT');
      expect(m.altAllele, 'AA');
      expect(m.refStart, 2);
      expect(m.refEnd, 4);
    });

    test('a single-base deletion is reported with the correct reference span', () {
      // Reference has an extra 'G' at position 2 that the query lacks.
      final result = MutationEngine.callFromAlignment('ACGTACGT', 'AC-TACGT');
      final m = result.mutations.single;
      expect(m.type, MutationType.deletion);
      expect(m.refAllele, 'G');
      expect(m.altAllele, '-');
      expect(m.refStart, 2);
      expect(m.refEnd, 3);
      expect(m.notation, '3delG');
      expect(result.deletionCount, 1);
    });

    test('a multi-base (3bp) deletion is reported as ONE block, not three', () {
      final result = MutationEngine.callFromAlignment('ACGTTTACGT', 'ACG---ACGT');
      expect(result.mutations, hasLength(1));
      final m = result.mutations.single;
      expect(m.type, MutationType.deletion);
      expect(m.refAllele, 'TTT');
      expect(m.refStart, 3);
      expect(m.refEnd, 6);
      expect(m.notation, '4_6delTTT');
      expect(result.deletionCount, 1);
    });

    test('a single-base insertion (gap in reference) is reported correctly', () {
      final result = MutationEngine.callFromAlignment('AC-TACGT', 'ACGTACGT');
      final m = result.mutations.single;
      expect(m.type, MutationType.insertion);
      expect(m.altAllele, 'G');
      expect(m.refAllele, '-');
      // Insertion occurs right after ungapped ref position 2.
      expect(m.refStart, 2);
      expect(m.refEnd, 2);
      expect(result.insertionCount, 1);
    });

    test('a multi-base insertion block is merged into one event', () {
      final result = MutationEngine.callFromAlignment('ACG---ACGT', 'ACGTTTACGT');
      final m = result.mutations.single;
      expect(m.type, MutationType.insertion);
      expect(m.altAllele, 'TTT');
      expect(result.insertionCount, 1);
    });

    test('mixed substitution + deletion + insertion are all detected independently', () {
      // ref: ACGTACGT   (10bp with an extra block for indel room)
      // Construct: substitution at pos0, deletion of 1bp at pos4, insertion after pos7.
      final ref = 'ACGTAC-GT';
      final qry = 'GCGT-CTGT';
      final result = MutationEngine.callFromAlignment(ref, qry);
      expect(result.mutations, hasLength(greaterThanOrEqualTo(2)));
      expect(result.snpCount, greaterThanOrEqualTo(1));
    });
  });

  group('MutationEngine.callFromAlignment — transition / transversion classification', () {
    test('purine<->purine substitution is classified as a transition', () {
      // A -> G is a transition.
      final result = MutationEngine.callFromAlignment('AAAA', 'GAAA');
      expect(result.mutations.single.isTransition, isTrue);
      expect(result.transitionCount, 1);
      expect(result.transversionCount, 0);
    });

    test('pyrimidine<->pyrimidine substitution is classified as a transition', () {
      // C -> T is a transition.
      final result = MutationEngine.callFromAlignment('CAAA', 'TAAA');
      expect(result.mutations.single.isTransition, isTrue);
    });

    test('purine<->pyrimidine substitution is classified as a transversion', () {
      // A -> C is a transversion.
      final result = MutationEngine.callFromAlignment('AAAA', 'CAAA');
      expect(result.mutations.single.isTransition, isFalse);
      expect(result.transversionCount, 1);
      expect(result.transitionCount, 0);
    });

    test('multi-base substitution blocks are not classified as transitions', () {
      final result = MutationEngine.callFromAlignment('AATT', 'GGTT');
      expect(result.mutations.single.isTransition, isFalse);
    });
  });

  group('MutationEngine.callFromAlignment — codon-impact classification', () {
    test('a synonymous (silent) substitution keeps the same amino acid', () {
      // Codon 0: GGT (Gly) -> GGC (Gly): 3rd position T->C, silent.
      final result = MutationEngine.callFromAlignment('GGTAAA', 'GGCAAA', codingFrameStart: 0);
      final m = result.mutations.single;
      expect(m.impact, MutationImpact.synonymous);
      expect(m.refCodon, 'GGT');
      expect(m.altCodon, 'GGC');
      expect(m.refAminoAcid, 'G');
      expect(m.altAminoAcid, 'G');
      expect(m.aminoAcidPosition, 1);
      expect(result.impactCounts[MutationImpact.synonymous], 1);
    });

    test('a missense substitution changes the translated amino acid', () {
      // Codon 0: TTT (Phe) -> TAT (Tyr): 2nd position T->A.
      final result = MutationEngine.callFromAlignment('TTTAAA', 'TATAAA', codingFrameStart: 0);
      final m = result.mutations.single;
      expect(m.impact, MutationImpact.missense);
      expect(m.refAminoAcid, 'F');
      expect(m.altAminoAcid, 'Y');
      expect(m.proteinNotation, 'p.F1Y');
    });

    test('a nonsense substitution introduces a premature stop codon', () {
      // Codon 0: TGG (Trp) -> TGA (Stop): 3rd position G->A.
      final result = MutationEngine.callFromAlignment('TGGAAA', 'TGAAAA', codingFrameStart: 0);
      final m = result.mutations.single;
      expect(m.impact, MutationImpact.nonsense);
      expect(m.altAminoAcid, '*');
    });

    test('an indel whose length is a multiple of 3 is an in-frame indel', () {
      // 3bp deletion inside the coding frame -> in-frame indel, not frameshift.
      final result = MutationEngine.callFromAlignment(
        'ATGAAATTTGGGTAA',
        'ATG---TTTGGGTAA',
        codingFrameStart: 0,
      );
      final m = result.mutations.single;
      expect(m.type, MutationType.deletion);
      expect(m.impact, MutationImpact.inFrameIndel);
    });

    test('an indel whose length is NOT a multiple of 3 is a frameshift', () {
      // 1bp deletion inside the coding frame -> frameshift.
      final result = MutationEngine.callFromAlignment(
        'ATGAAATTTGGGTAA',
        'ATG-AATTTGGGTAA',
        codingFrameStart: 0,
      );
      final m = result.mutations.single;
      expect(m.type, MutationType.deletion);
      expect(m.impact, MutationImpact.frameshift);
    });

    test('mutations before the coding frame start are marked non-coding', () {
      final result = MutationEngine.callFromAlignment('AAATGCCC', 'GAATGCCC', codingFrameStart: 3);
      final m = result.mutations.single;
      expect(m.refStart, 0);
      expect(m.impact, MutationImpact.nonCoding);
    });

    test('no coding frame specified leaves mutations positionally reported only', () {
      final result = MutationEngine.callFromAlignment('AAAA', 'AGAA');
      expect(result.mutations.single.impact, MutationImpact.unknown);
      expect(result.notes.any((n) => n.contains('No coding frame specified')), isTrue);
    });
  });

  group('MutationEngine.missenseSeverity', () {
    test('returns a positive BLOSUM62 score for a conservative substitution (F->Y)', () {
      final result = MutationEngine.callFromAlignment('TTTAAA', 'TATAAA', codingFrameStart: 0);
      final m = result.mutations.single;
      expect(m.impact, MutationImpact.missense);
      final severity = MutationEngine.missenseSeverity(m);
      expect(severity, greaterThan(0)); // F<->Y is a conservative aromatic substitution
    });

    test('returns 0 when the mutation has no amino-acid classification', () {
      final result = MutationEngine.callFromAlignment('AAAA', 'AGAA'); // no coding frame
      final m = result.mutations.single;
      expect(MutationEngine.missenseSeverity(m), 0);
    });
  });

  group('MutationEngine.callFromAlignment — toMapFeatures()', () {
    test('converts mutation calls into genome-map features with matching categories', () {
      final result = MutationEngine.callFromAlignment('ACGTACGT', 'ACGTGCGT');
      final features = result.toMapFeatures();
      expect(features, hasLength(1));
      expect(features.single.category, 'snp');
      expect(features.single.start, 4);
      expect(features.single.label, '5A>G');
    });
  });

  group('MutationEngine.analyze — convenience wrapper over raw sequences', () {
    test('aligns and calls variants end-to-end for two unaligned sequences', () {
      final result = MutationEngine.analyze('ACGTACGTACGT', 'ACGTAGGTACGT');
      expect(result.mutations, isNotEmpty);
      expect(result.referenceLength, 12);
      expect(result.queryLength, 12);
    });
  });
}
