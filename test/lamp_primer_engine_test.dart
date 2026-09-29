import 'package:flutter_test/flutter_test.dart';
import 'package:genome_analyzer/engines/lamp_primer_engine.dart';
import 'package:genome_analyzer/engines/sequence_engine.dart';

String _randomSeq(int len, int seed) {
  const bases = 'ACGT';
  int s = seed;
  final sb = StringBuffer();
  for (int i = 0; i < len; i++) {
    // simple LCG for deterministic pseudo-random sequence
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    sb.write(bases[s % 4]);
  }
  return sb.toString();
}

void main() {
  group('LampPrimerEngine', () {
    test('returns empty list for templates shorter than 150 nt', () {
      final result = LampPrimerEngine.designLampPrimers('ACGT' * 10);
      expect(result, isEmpty);
    });

    test('designs at least one valid LAMP primer set for a long template', () {
      final template = _randomSeq(400, 42);
      final sets = LampPrimerEngine.designLampPrimers(template, maxSets: 6);
      expect(sets, isNotEmpty);

      final set = sets.first;
      // Basic sanity on lengths
      expect(set.f3.length, greaterThanOrEqualTo(18));
      expect(set.b3.length, greaterThanOrEqualTo(18));
      expect(set.fip.length, equals(set.f1c.length + set.f2.length));
      expect(set.bip.length, equals(set.b1c.length + set.b2.length));

      // F-side ordering on the template: F3 < F2 < F1c
      expect(set.f3.templateStart, lessThan(set.f2.templateStart));
      expect(set.f2.templateEnd, lessThanOrEqualTo(set.f1c.templateStart));

      // B-side ordering on the template: F1c < B1 < B2 < B3
      expect(set.f1c.templateEnd, lessThanOrEqualTo(set.b1c.templateStart));
      expect(set.b1c.templateEnd, lessThanOrEqualTo(set.b2.templateStart));
      expect(set.b2.templateEnd, lessThanOrEqualTo(set.b3.templateStart));

      // Verify F1c is indeed the reverse complement of the F1 template
      // region it was derived from (self-consistency check).
      final f1Region = template.substring(
        set.f1c.templateStart,
        set.f1c.templateEnd,
      );
      expect(
        set.f1c.sequence,
        equals(SequenceEngine.reverseComplement(f1Region)),
      );

      // Verify B2 is the reverse complement of its own template region.
      final b2Region = template.substring(
        set.b2.templateStart,
        set.b2.templateEnd,
      );
      expect(
        set.b2.sequence,
        equals(SequenceEngine.reverseComplement(b2Region)),
      );

      // Score should be within 0-100.
      expect(set.score, inInclusiveRange(0, 100));

      // Amplicon core (F1-B1 gap) should be non-negative.
      expect(set.ampliconCoreSize, greaterThanOrEqualTo(0));

      // Total span must be positive and within the template.
      expect(set.totalSpan, greaterThan(0));
      expect(set.b3.templateEnd - set.f3.templateStart, equals(set.totalSpan));
    });

    test('sets are sorted by descending score', () {
      final template = _randomSeq(500, 7);
      final sets = LampPrimerEngine.designLampPrimers(template, maxSets: 6);
      for (int i = 1; i < sets.length; i++) {
        expect(sets[i - 1].score, greaterThanOrEqualTo(sets[i].score));
      }
    });

    test('can optionally disable loop primers', () {
      final template = _randomSeq(400, 99);
      final sets = LampPrimerEngine.designLampPrimers(
        template,
        includeLoopPrimers: false,
        maxSets: 3,
      );
      expect(sets, isNotEmpty);
      for (final s in sets) {
        expect(s.lf, isNull);
        expect(s.lb, isNull);
        expect(s.hasLoopPrimers, isFalse);
      }
    });
  });
}
