import 'dart:math';
import '../models/analysis_models.dart';
import '../models/bio_sequence.dart';
import 'proteomics_engine.dart';
import 'sequence_engine.dart';

/// Generates idealized, schematic 3D coordinates for nucleic-acid double
/// helices and protein backbones, plus a stability/thermostability summary
/// derived from composition metrics.
///
/// HONESTY NOTE: this is NOT structure prediction (no AlphaFold-level fold
/// prediction, no molecular-dynamics simulation). DNA is rendered using
/// standard idealized B-form helical parameters; proteins are rendered as
/// a schematic ribbon whose local geometry (helix/strand/coil) follows a
/// simplified per-residue Chou-Fasman-based secondary-structure guess —
/// useful for visual intuition, not for structural biology conclusions.
class Structure3DEngine {
  static Structure3DResult dnaHelix(String seq, {int maxBases = 120}) {
    final s = seq.toUpperCase().replaceAll('U', 'T');
    final truncated = s.length > maxBases ? s.substring(0, maxBases) : s;
    final atoms = <Atom3D>[];
    final bonds = <List<int>>[];
    const rise = 3.0; // Å-like unit, scaled for display
    const radius = 9.0;
    const twistDeg = 34.0; // ~10.5 bp/turn, B-DNA

    for (int i = 0; i < truncated.length; i++) {
      final angle = i * twistDeg * pi / 180;
      final z = i * rise;
      // Strand 1 (5'->3' given sequence)
      final x1 = radius * cos(angle);
      final y1 = radius * sin(angle);
      atoms.add(Atom3D(x: x1, y: y1, z: z, label: truncated[i], kind: 'helix'));
      // Strand 2 (complementary, offset 180° across the helix axis)
      final compChar = SequenceEngine.complement(truncated[i]);
      final x2 = radius * cos(angle + pi);
      final y2 = radius * sin(angle + pi);
      atoms.add(Atom3D(x: x2, y: y2, z: z, label: compChar, kind: 'sheet'));
    }

    for (int i = 0; i < truncated.length; i++) {
      final strand1Idx = i * 2;
      final strand2Idx = i * 2 + 1;
      if (i > 0) {
        bonds.add([strand1Idx - 2, strand1Idx]); // backbone strand 1
        bonds.add([strand2Idx - 2, strand2Idx]); // backbone strand 2
      }
      bonds.add([strand1Idx, strand2Idx]); // base-pair rung
    }

    return Structure3DResult(
      atoms: atoms,
      bonds: bonds,
      modelKind: 'dna_helix',
    );
  }

  static Structure3DResult proteinBackbone(
    String protein, {
    int maxResidues = 150,
  }) {
    final full = ProteomicsEngine.cleanProtein(protein);
    final seq = full.length > maxResidues
        ? full.substring(0, maxResidues)
        : full;
    final ss = ProteomicsEngine.perResidueSecondaryStructure(seq);

    final atoms = <Atom3D>[];
    final bonds = <List<int>>[];
    double z = 0;
    double segAngle = 0;
    String? lastClass;

    for (int i = 0; i < seq.length; i++) {
      final cls = ss[i];
      if (cls != lastClass) {
        segAngle = 0;
        lastClass = cls;
      }
      double x, y;
      switch (cls) {
        case 'Helix':
          final rad = segAngle * pi / 180;
          x = 2.3 * cos(rad);
          y = 2.3 * sin(rad);
          z += 1.5;
          segAngle += 100;
          break;
        case 'Sheet':
          x = (i % 2 == 0) ? 1.6 : -1.6;
          y = 0;
          z += 3.2;
          break;
        default:
          x = sin(i * 0.5) * 2.5;
          y = cos(i * 0.7) * 2.0;
          z += 2.2;
      }
      atoms.add(
        Atom3D(x: x, y: y, z: z, label: seq[i], kind: cls.toLowerCase()),
      );
      if (i > 0) bonds.add([i - 1, i]);
    }

    return Structure3DResult(
      atoms: atoms,
      bonds: bonds,
      modelKind: 'protein_backbone',
    );
  }

  static int _longestHomopolymer(String seq) {
    if (seq.isEmpty) return 0;
    int best = 1, cur = 1;
    for (int i = 1; i < seq.length; i++) {
      if (seq[i] == seq[i - 1]) {
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 1;
      }
    }
    return best;
  }

  static StabilityReport buildStabilityReport(BioSequence seq) {
    final observations = <String>[];
    String assessment = 'Unknown';
    double? tm;
    double? gravy;
    double? aliphatic;

    if (seq.type == SequenceType.dna || seq.type == SequenceType.rna) {
      final gc = SequenceEngine.gcContent(seq.sequence);
      final homopolymer = _longestHomopolymer(seq.sequence);
      // Simplified Tm estimate for longer sequences (empirical formula,
      // valid mainly for >14 bp under standard salt conditions).
      tm = 64.9 + 41 * (gc / 100 * seq.length - 16.4) / seq.length;

      if (gc >= 60) {
        observations.add(
          'High GC content (${gc.toStringAsFixed(1)}%) — G-C base pairs form '
          '3 hydrogen bonds vs. 2 for A-T, so this duplex is likely thermally '
          'stable and resistant to denaturation.',
        );
        assessment = 'Thermally stable (GC-rich)';
      } else if (gc >= 40) {
        observations.add(
          'Moderate GC content (${gc.toStringAsFixed(1)}%) — typical stability '
          'for most genomic sequences.',
        );
        assessment = 'Moderate stability';
      } else {
        observations.add(
          'Low GC / AT-rich content (${gc.toStringAsFixed(1)}%) — weaker A-T '
          'base pairing means this region may denature/melt more easily '
          '(AT-rich regions are also common in promoters and origins of replication).',
        );
        assessment = 'Lower thermal stability (AT-rich)';
      }

      if (homopolymer >= 6) {
        observations.add(
          'Long homopolymer run detected ($homopolymer identical consecutive bases) — '
          'such repeats can increase secondary-structure/slippage risk and '
          'reduce sequencing/PCR reliability.',
        );
      }
      observations.add(
        'Estimated melting temperature (empirical GC-content formula): '
        '${tm.toStringAsFixed(1)} °C (approximate — real Tm depends on salt '
        'concentration, exact neighbor-pair thermodynamics, and secondary structure).',
      );
    } else if (seq.type == SequenceType.protein) {
      final props = ProteomicsEngine.analyze(seq.sequence);
      gravy = props.gravyScore;
      aliphatic = props.aliphaticIndex;

      if (gravy > 0) {
        observations.add(
          'Positive GRAVY score (${gravy.toStringAsFixed(2)}) — net '
          'hydrophobic character, consistent with a membrane-associated or '
          'poorly soluble protein.',
        );
      } else {
        observations.add(
          'Negative GRAVY score (${gravy.toStringAsFixed(2)}) — net '
          'hydrophilic character, consistent with a soluble, cytoplasmic-type protein.',
        );
      }

      if (aliphatic > 80) {
        observations.add(
          'High aliphatic index (${aliphatic.toStringAsFixed(1)}) — this is an '
          'empirical correlate of increased thermostability across proteins '
          '(Ikai, 1980).',
        );
        assessment = 'Higher predicted thermostability';
      } else if (aliphatic > 50) {
        observations.add(
          'Moderate aliphatic index (${aliphatic.toStringAsFixed(1)}).',
        );
        assessment = 'Moderate predicted thermostability';
      } else {
        observations.add(
          'Low aliphatic index (${aliphatic.toStringAsFixed(1)}) — lower '
          'empirical thermostability correlate.',
        );
        assessment = 'Lower predicted thermostability';
      }

      if (props.numCysteines >= 2) {
        observations.add(
          '${props.numCysteines} cysteine residues present — potential '
          'disulfide bond formation could add structural rigidity/stability '
          '(actual bonding depends on the folded 3D structure and cellular redox environment).',
        );
      }
    } else {
      observations.add('Sequence type unknown — cannot assess stability.');
      assessment = 'Unknown';
    }

    return StabilityReport(
      sequenceName: seq.name,
      type: seq.type,
      observations: observations,
      overallAssessment: assessment,
      estimatedTm: tm,
      gravy: gravy,
      aliphaticIndex: aliphatic,
    );
  }
}
