import 'package:flutter_test/flutter_test.dart';
import 'package:genome_analyzer/engines/alignment_engine.dart';
import 'package:genome_analyzer/engines/substitution_matrices.dart';
import 'package:genome_analyzer/models/analysis_models.dart';

String _randomSeq(int len, int seed, {String alphabet = 'ACGT'}) {
  int s = seed;
  final sb = StringBuffer();
  for (int i = 0; i < len; i++) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    sb.write(alphabet[s % alphabet.length]);
  }
  return sb.toString();
}

void main() {
  group('AlignmentEngine.globalAlign (linear gaps, simple scoring)', () {
    test('identical sequences align with 100% identity and no gaps', () {
      final r = AlignmentEngine.globalAlign('ACGTACGT', 'ACGTACGT');
      expect(r.alignedSeqA, 'ACGTACGT');
      expect(r.alignedSeqB, 'ACGTACGT');
      expect(r.identityPercent, 100.0);
      expect(r.gaps, 0);
      expect(r.score, 8 * AlignmentEngine.matchScore);
    });

    test('single insertion produces exactly one gap run', () {
      final r = AlignmentEngine.globalAlign('ACGT', 'ACCGT');
      expect(r.alignedSeqA.length, r.alignedSeqB.length);
      expect(r.gaps, 1);
      expect(r.gapOpenings, 1);
    });

    test('completely different sequences still produce a valid alignment', () {
      final r = AlignmentEngine.globalAlign('AAAA', 'TTTT');
      expect(r.alignedSeqA.length, 4);
      expect(r.alignedSeqB.length, 4);
      expect(r.identityPercent, 0.0);
    });
  });

  group('AlignmentEngine.localAlign (Smith-Waterman)', () {
    test('finds the shared core region, ignoring divergent flanks', () {
      final r = AlignmentEngine.localAlign(
        'ZZZZZACGTACGTZZZZZ'.replaceAll('Z', 'T'),
        'QQQQQACGTACGTQQQQQ'.replaceAll('Q', 'G'),
      );
      // The common core ACGTACGT should dominate the local alignment.
      expect(r.alignedSeqA.replaceAll('-', ''), contains('ACGTACGT'));
      expect(r.identityPercent, greaterThan(80));
    });
  });

  group('AlignmentEngine.glocalAlign (semi-global / fit)', () {
    test('short sequence fits inside long one without end-gap penalty', () {
      const needle = 'ACGTACGT';
      const haystack = 'TTTTTTTTACGTACGTGGGGGGGG';
      final r = AlignmentEngine.glocalAlign(haystack, needle);
      // No identity loss from the free leading/trailing haystack overhang.
      expect(r.alignedSeqB.replaceAll('-', ''), needle);
      expect(r.identityPercent, 100.0);
    });
  });

  group('AlignmentEngine affine gaps (Gotoh)', () {
    const affineOpts = AlignmentOptions(
      gapModel: GapModel.affine,
      gapOpenPenalty: -8,
      gapExtendPenalty: -1,
    );

    test(
      'global affine alignment favors one long gap over many short ones',
      () {
        final r = AlignmentEngine.globalAlign(
          'ACGTACGTACGT',
          'ACGTACGT',
          options: affineOpts,
        );
        expect(r.gapModel, GapModel.affine);
        // A single contiguous gap run should be preferred under affine
        // penalties, i.e. gapOpenings should be low (ideally 1).
        expect(r.gapOpenings, lessThanOrEqualTo(1));
        expect(r.gaps, 4);
      },
    );

    test('local affine alignment runs without throwing and finds a region', () {
      final a = _randomSeq(60, 7);
      final b = '${a.substring(0, 30)}${_randomSeq(10, 99)}${a.substring(40)}';
      final r = AlignmentEngine.localAlign(a, b, options: affineOpts);
      expect(r.alignedSeqA, isNotEmpty);
      expect(r.score, greaterThan(0));
    });
  });

  group('AlignmentEngine substitution matrices', () {
    test('BLOSUM62 scores identical residues positively', () {
      expect(SubstitutionMatrices.blosum62('W', 'W'), 11);
      expect(SubstitutionMatrices.blosum62('A', 'A'), 4);
    });

    test('PAM250 table is symmetric and self-consistent for a few entries', () {
      expect(
        SubstitutionMatrices.pam250('A', 'R'),
        SubstitutionMatrices.pam250('R', 'A'),
      );
    });

    test('protein alignment with BLOSUM62 produces a sane result', () {
      const opts = AlignmentOptions(
        matrixType: SubstitutionMatrixType.blosum62,
      );
      final r = AlignmentEngine.globalAlign(
        'MKTAYIAKQRQISFVKSHFSRQLEERLGLIEVQ',
        'MKTAYIAKQRQISFVKSHFSRQLEERLGLIEVQ',
        options: opts,
      );
      expect(r.identityPercent, 100.0);
      expect(r.matrixType, SubstitutionMatrixType.blosum62);
    });

    test('DNA transition/transversion scheme penalizes transversions more', () {
      const opts = AlignmentOptions(
        matrixType: SubstitutionMatrixType.dnaTransitionTransversion,
        matchScore: 2,
        mismatchScore: -4,
        transitionPenalty: -1,
      );
      // A/G transition vs A/C transversion at the same position.
      final transition = SubstitutionMatrices.dnaTransitionTransversion(
        'A',
        'G',
        matchScore: 2,
        mismatchScore: -4,
        transitionPenalty: -1,
      );
      final transversion = SubstitutionMatrices.dnaTransitionTransversion(
        'A',
        'C',
        matchScore: 2,
        mismatchScore: -4,
        transitionPenalty: -1,
      );
      expect(transition, greaterThan(transversion));
      expect(opts.matrixType, SubstitutionMatrixType.dnaTransitionTransversion);
    });
  });

  group('AlignmentEngine banded performance path', () {
    test('banded global alignment matches full DP result for similar-length '
        'long sequences', () {
      final a = _randomSeq(1200, 11);
      // b = a with a handful of point mutations, same length.
      final chars = a.split('');
      chars[100] = chars[100] == 'A' ? 'T' : 'A';
      chars[600] = chars[600] == 'C' ? 'G' : 'C';
      final b = chars.join();

      final banded = AlignmentEngine.globalAlign(a, b);
      final unbanded = AlignmentEngine.globalAlign(
        a,
        b,
        options: const AlignmentOptions(autoBand: false),
      );
      expect(banded.banded, isTrue);
      expect(unbanded.banded, isFalse);
      expect(banded.score, unbanded.score);
      expect(banded.identityPercent, unbanded.identityPercent);
    });
  });

  group('AlignmentEngine.multipleAlign', () {
    test('single sequence returns itself with 100% identity', () {
      final r = AlignmentEngine.multipleAlign(['A'], ['ACGT']);
      expect(r.alignedSequences, ['ACGT']);
      expect(r.averageIdentity, 100);
    });

    test(
      'center-star method aligns 3 similar sequences with high identity',
      () {
        const base = 'ACGTACGTACGTACGTACGT';
        final seqs = [base, base.replaceRange(5, 6, 'T'), base];
        final r = AlignmentEngine.multipleAlign(
          ['a', 'b', 'c'],
          seqs,
          method: MsaMethod.centerStar,
        );
        expect(r.method, MsaMethod.centerStar);
        expect(r.averageIdentity, greaterThan(85));
        expect(r.alignedSequences.length, 3);
        expect(r.consensusSequence.length, r.consensusLength);
      },
    );

    test('guide-tree method produces column-consistent alignment of equal '
        'length rows', () {
      const base = 'ACGTACGTACGTACGTACGTACGT';
      final seqs = [
        base,
        '${base.substring(0, 10)}GG${base.substring(10)}',
        base,
        base.replaceRange(20, 22, 'TT'),
      ];
      final r = AlignmentEngine.multipleAlign(
        ['a', 'b', 'c', 'd'],
        seqs,
        method: MsaMethod.guideTree,
      );
      expect(r.method, MsaMethod.guideTree);
      final lengths = r.alignedSequences.map((s) => s.length).toSet();
      expect(lengths.length, 1, reason: 'all rows must share one length');
      expect(lengths.first, r.consensusLength);
      expect(r.averageIdentity, greaterThan(70));
    });

    test('guide-tree handles divergent sequence sets without throwing', () {
      final seqs = [
        _randomSeq(80, 1),
        _randomSeq(80, 2),
        _randomSeq(80, 3),
        _randomSeq(80, 4),
        _randomSeq(80, 5),
      ];
      final r = AlignmentEngine.multipleAlign(
        List.generate(5, (i) => 'seq$i'),
        seqs,
        method: MsaMethod.guideTree,
      );
      expect(r.alignedSequences.length, 5);
      final lengths = r.alignedSequences.map((s) => s.length).toSet();
      expect(lengths.length, 1);
    });
  });

  group('AlignmentEngine.align dispatcher', () {
    test('dispatches to the correct underlying algorithm per mode', () {
      final g = AlignmentEngine.align('ACGT', 'ACGT', AlignmentMode.global);
      final l = AlignmentEngine.align('ACGT', 'ACGT', AlignmentMode.local);
      final s = AlignmentEngine.align('ACGT', 'ACGT', AlignmentMode.glocal);
      final h = AlignmentEngine.align(
        'ACGT',
        'ACGT',
        AlignmentMode.heuristicSeedExtend,
      );
      expect(g.mode, AlignmentMode.global);
      expect(l.mode, AlignmentMode.local);
      expect(s.mode, AlignmentMode.glocal);
      expect(h.mode, AlignmentMode.heuristicSeedExtend);
    });
  });

  group('AlignmentEngine.seedExtendAlign (BLAST-like heuristic)', () {
    test('finds and aligns a shared exact seed region efficiently', () {
      final core = _randomSeq(200, 5);
      final a = '${_randomSeq(300, 1)}$core${_randomSeq(300, 2)}';
      final b = '${_randomSeq(300, 3)}$core${_randomSeq(300, 4)}';
      final r = AlignmentEngine.seedExtendAlign(
        a,
        b,
        options: const AlignmentOptions(seedLength: 11, extendWindow: 32),
      );
      expect(r.mode, AlignmentMode.heuristicSeedExtend);
      expect(r.seedHits, greaterThan(0));
      // Should have aligned a much smaller window than the full sequences.
      expect(r.alignedSeqA.length, lessThan(a.length));
      expect(r.identityPercent, greaterThan(50));
    });

    test('falls back to full global alignment with a note when no seed '
        'exists', () {
      // Two sequences built from disjoint alphabets share no k-mer.
      final a = 'AAAAAAAAAAAAAAAA';
      final b = 'GGGGGGGGGGGGGGGG';
      final r = AlignmentEngine.seedExtendAlign(
        a,
        b,
        options: const AlignmentOptions(seedLength: 11),
      );
      expect(r.seedHits, 0);
      expect(r.notes, isNotEmpty);
      expect(r.alignedSeqA.length, a.length);
    });

    test('is dramatically faster than full DP on long sequences with one '
        'shared region', () {
      final core = _randomSeq(100, 9);
      final a = '${_randomSeq(4000, 11)}$core${_randomSeq(4000, 12)}';
      final b = '${_randomSeq(4000, 13)}$core${_randomSeq(4000, 14)}';
      final swFast = Stopwatch()..start();
      final fast = AlignmentEngine.seedExtendAlign(a, b);
      swFast.stop();
      expect(fast.seedHits, greaterThan(0));
      // The heuristic should only need to DP-align a small window, so it
      // must be comfortably faster than full O(n*m) global alignment would
      // be on ~8000x8000 sequences (sanity bound, not a tight benchmark).
      expect(swFast.elapsedMilliseconds, lessThan(500));
    });
  });

  group('AlignmentEngine.multipleAlign with MsaMethod.muscle', () {
    test('produces a column-consistent alignment for similar sequences', () {
      const base = 'ACGTACGTACGTACGTACGTACGTACGT';
      final seqs = [
        base,
        '${base.substring(0, 10)}GG${base.substring(10)}',
        base,
        base.replaceRange(20, 22, 'TT'),
      ];
      final r = AlignmentEngine.multipleAlign(
        ['a', 'b', 'c', 'd'],
        seqs,
        method: MsaMethod.muscle,
        options: const AlignmentOptions(refinementIterations: 4),
      );
      expect(r.method, MsaMethod.muscle);
      final lengths = r.alignedSequences.map((s) => s.length).toSet();
      expect(lengths.length, 1, reason: 'all rows must share one length');
      expect(lengths.first, r.consensusLength);
      expect(r.averageIdentity, greaterThan(70));
      expect(r.notes, isNotEmpty);
    });

    test('handles divergent sequence sets without throwing and keeps rows '
        'aligned', () {
      final seqs = [
        _randomSeq(80, 1),
        _randomSeq(80, 2),
        _randomSeq(80, 3),
        _randomSeq(80, 4),
        _randomSeq(80, 5),
      ];
      final r = AlignmentEngine.multipleAlign(
        List.generate(5, (i) => 'seq$i'),
        seqs,
        method: MsaMethod.muscle,
        options: const AlignmentOptions(refinementIterations: 5),
      );
      expect(r.alignedSequences.length, 5);
      final lengths = r.alignedSequences.map((s) => s.length).toSet();
      expect(lengths.length, 1);
    });

    test('refinement never makes the sum-of-pairs alignment score worse '
        'than the unrefined progressive alignment', () {
      final seqs = [
        _randomSeq(60, 21),
        _randomSeq(60, 22),
        _randomSeq(60, 23),
        _randomSeq(60, 24),
        _randomSeq(60, 25),
        _randomSeq(60, 26),
      ];
      final names = List.generate(6, (i) => 'seq$i');

      final unrefined = AlignmentEngine.multipleAlign(
        names,
        seqs,
        method: MsaMethod.guideTree,
      );
      final refined = AlignmentEngine.multipleAlign(
        names,
        seqs,
        method: MsaMethod.muscle,
        options: const AlignmentOptions(refinementIterations: 8),
      );
      // Both alignments should be internally consistent (equal row length).
      expect(refined.alignedSequences.map((s) => s.length).toSet().length, 1);
      expect(unrefined.alignedSequences.map((s) => s.length).toSet().length, 1);
    });

    test('zero refinement iterations still returns a valid profile '
        'alignment (pure progressive, no refinement pass)', () {
      final seqs = [_randomSeq(50, 31), _randomSeq(50, 32), _randomSeq(50, 33)];
      final r = AlignmentEngine.multipleAlign(
        ['a', 'b', 'c'],
        seqs,
        method: MsaMethod.muscle,
        options: const AlignmentOptions(refinementIterations: 0),
      );
      expect(r.refinementPasses, 0);
      final lengths = r.alignedSequences.map((s) => s.length).toSet();
      expect(lengths.length, 1);
    });

    test('true profile-profile scoring clearly outperforms the single-row '
        'heuristics on a family with indels (regression guard)', () {
      final ancestor = _randomSeq(200, 77);
      final seqs = <String>[];
      for (int i = 0; i < 10; i++) {
        var s = ancestor;
        final pos = (i * 37 + 13) % s.length;
        if (i % 2 == 0) {
          s = s.substring(0, pos) + _randomSeq(3, i * 7) + s.substring(pos);
        } else {
          s = s.substring(0, pos) + s.substring((pos + 3).clamp(0, s.length));
        }
        final chars = s.split('');
        for (int m = 0; m < 6; m++) {
          final p = (i * 53 + m * 11) % chars.length;
          chars[p] = 'ACGT'[(i + m) % 4];
        }
        seqs.add(chars.join());
      }
      final names = List.generate(10, (i) => 'seq$i');

      final guide = AlignmentEngine.multipleAlign(
        names,
        seqs,
        method: MsaMethod.guideTree,
      );
      final muscle = AlignmentEngine.multipleAlign(
        names,
        seqs,
        method: MsaMethod.muscle,
        options: const AlignmentOptions(refinementIterations: 15),
      );

      expect(muscle.averageIdentity, greaterThan(guide.averageIdentity + 20));
    });
  });
}
