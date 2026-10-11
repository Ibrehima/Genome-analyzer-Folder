import '../models/analysis_models.dart';
import 'alignment_engine.dart';
import 'sequence_engine.dart';
import 'substitution_matrices.dart';

/// Detects, classifies and characterizes mutations (substitutions /
/// insertions / deletions) between a reference and a query sequence.
///
/// Workflow:
///  1. The two sequences are globally aligned (if not already pre-aligned
///     with '-' gap characters) so every position lines up.
///  2. Adjacent single-column differences of the same type are merged into
///     block-level events (so a 3bp deletion reports as ONE deletion, not
///     three separate single-base ones) — this matches how real variant
///     callers (e.g. VCF) represent indels.
///  3. If [codingFrameStart] is given, each event occurring inside that
///     reading frame is further classified by its effect on the translated
///     protein (synonymous / missense / nonsense / frameshift / in-frame
///     indel), by comparing the reference vs mutated codon(s).
///
/// HONESTY NOTE: codon-impact classification assumes [codingFrameStart] is
/// the correct start of an open reading frame on the reference (0-based).
/// For sequences with multiple/unknown reading frames, impact prediction is
/// only run on the frame you specify — this is a simplified, in-app
/// substitute for tools like Ensembl VEP or SnpEff, not a full annotation
/// pipeline with transcript/exon models.
class MutationEngine {
  /// Aligns [reference] and [query] (global alignment) then calls variants.
  /// Convenience wrapper around [callFromAlignment] for raw, un-aligned
  /// input sequences.
  static MutationAnalysisResult analyze(
    String reference,
    String query, {
    int? codingFrameStart,
    AlignmentOptions? options,
  }) {
    final opts = options ?? const AlignmentOptions();
    final aligned = AlignmentEngine.align(reference, query, AlignmentMode.global, options: opts);
    return callFromAlignment(
      aligned.alignedSeqA,
      aligned.alignedSeqB,
      codingFrameStart: codingFrameStart,
    );
  }

  /// Calls variants directly from two already-aligned (equal-length, '-'
  /// gapped) sequences — e.g. one row pair pulled out of an MSA result.
  static MutationAnalysisResult callFromAlignment(
    String alignedRef,
    String alignedQuery, {
    int? codingFrameStart,
  }) {
    final notes = <String>[];
    final len = alignedRef.length < alignedQuery.length ? alignedRef.length : alignedQuery.length;

    // Step 1: raw per-column diffs, tracking ungapped reference coordinates.
    final List<MutationRecord> raw = [];
    int refPos = 0; // ungapped position in the reference

    int i = 0;
    while (i < len) {
      final r = alignedRef[i];
      final q = alignedQuery[i];
      if (r == q) {
        if (r != '-') refPos++;
        i++;
        continue;
      }
      if (r != '-' && q != '-') {
        // Substitution — merge consecutive substitution columns (MNP-style
        // block) into one record.
        int j = i;
        final refBuf = StringBuffer();
        final altBuf = StringBuffer();
        final startRef = refPos;
        while (j < len &&
            alignedRef[j] != '-' &&
            alignedQuery[j] != '-' &&
            alignedRef[j] != alignedQuery[j]) {
          refBuf.write(alignedRef[j]);
          altBuf.write(alignedQuery[j]);
          refPos++;
          j++;
        }
        final refAllele = refBuf.toString();
        final altAllele = altBuf.toString();
        final isTransition =
            refAllele.length == 1 && altAllele.length == 1 && _isTransition(refAllele, altAllele);
        raw.add(
          MutationRecord(
            refStart: startRef,
            refEnd: refPos,
            refAllele: refAllele,
            altAllele: altAllele,
            type: MutationType.substitution,
            isTransition: isTransition,
          ),
        );
        i = j;
        continue;
      }
      if (r == '-' && q != '-') {
        // Insertion in query relative to reference — merge consecutive gap
        // columns into one insertion block.
        int j = i;
        final altBuf = StringBuffer();
        final atRef = refPos;
        while (j < len && alignedRef[j] == '-' && alignedQuery[j] != '-') {
          altBuf.write(alignedQuery[j]);
          j++;
        }
        raw.add(
          MutationRecord(
            refStart: atRef,
            refEnd: atRef,
            refAllele: '-',
            altAllele: altBuf.toString(),
            type: MutationType.insertion,
          ),
        );
        i = j;
        continue;
      }
      // r != '-' && q == '-' : deletion
      {
        int j = i;
        final refBuf = StringBuffer();
        final startRef = refPos;
        while (j < len && alignedRef[j] != '-' && alignedQuery[j] == '-') {
          refBuf.write(alignedRef[j]);
          refPos++;
          j++;
        }
        raw.add(
          MutationRecord(
            refStart: startRef,
            refEnd: refPos,
            refAllele: refBuf.toString(),
            altAllele: '-',
            type: MutationType.deletion,
          ),
        );
        i = j;
      }
    }

    // Step 2: optional codon-impact classification.
    List<MutationRecord> finalRecords = raw;
    if (codingFrameStart != null) {
      final refUngapped = alignedRef.replaceAll('-', '');
      finalRecords = raw.map((m) => _classifyImpact(m, refUngapped, codingFrameStart)).toList();
      notes.add(
        'Codon-impact classification was run assuming an open reading frame '
        'starting at reference position ${codingFrameStart + 1} (1-based). '
        'This is a simplified single-frame analysis, not a full transcript/'
        'exon-aware annotation (see Ensembl VEP / SnpEff for that).',
      );
    } else {
      notes.add(
        'No coding frame specified — mutations are reported positionally '
        'only, without protein-impact classification.',
      );
    }

    final impactCounts = <MutationImpact, int>{};
    for (final m in finalRecords) {
      impactCounts[m.impact] = (impactCounts[m.impact] ?? 0) + 1;
    }

    return MutationAnalysisResult(
      mutations: finalRecords,
      referenceLength: alignedRef.replaceAll('-', '').length,
      queryLength: alignedQuery.replaceAll('-', '').length,
      impactCounts: impactCounts,
      notes: notes,
    );
  }

  static bool _isTransition(String a, String b) {
    const purines = {'A', 'G'};
    const pyrimidines = {'C', 'T', 'U'};
    final bothPurine = purines.contains(a) && purines.contains(b);
    final bothPyrimidine = pyrimidines.contains(a) && pyrimidines.contains(b);
    return bothPurine || bothPyrimidine;
  }

  static MutationRecord _classifyImpact(MutationRecord m, String refUngapped, int frameStart) {
    if (m.refStart < frameStart) {
      return _withImpact(m, MutationImpact.nonCoding);
    }

    if (m.type == MutationType.substitution && m.refAllele.length == 1 && m.altAllele.length == 1) {
      final relPos = m.refStart - frameStart;
      final codonIndex = relPos ~/ 3;
      final codonStart = frameStart + codonIndex * 3;
      if (codonStart + 3 > refUngapped.length) {
        return _withImpact(m, MutationImpact.unknown);
      }
      final refCodon = refUngapped.substring(codonStart, codonStart + 3);
      final posInCodon = relPos % 3;
      final altCodon =
          refCodon.substring(0, posInCodon) + m.altAllele + refCodon.substring(posInCodon + 1);
      final refAa = SequenceEngine.translate(refCodon);
      final altAa = SequenceEngine.translate(altCodon);
      MutationImpact impact;
      if (refAa == altAa) {
        impact = MutationImpact.synonymous;
      } else if (altAa == '*' && refAa != '*') {
        impact = MutationImpact.nonsense;
      } else {
        impact = MutationImpact.missense;
      }
      return MutationRecord(
        id: m.id,
        refStart: m.refStart,
        refEnd: m.refEnd,
        refAllele: m.refAllele,
        altAllele: m.altAllele,
        type: m.type,
        isTransition: m.isTransition,
        impact: impact,
        refCodon: refCodon,
        altCodon: altCodon,
        refAminoAcid: refAa,
        altAminoAcid: altAa,
        aminoAcidPosition: codonIndex + 1,
      );
    }

    // Indels: frameshift unless the length change is a multiple of 3.
    final indelLen = m.type == MutationType.insertion ? m.altAllele.length : m.refAllele.length;
    final impact = indelLen % 3 == 0 ? MutationImpact.inFrameIndel : MutationImpact.frameshift;
    return _withImpact(m, impact);
  }

  static MutationRecord _withImpact(MutationRecord m, MutationImpact impact) {
    return MutationRecord(
      id: m.id,
      refStart: m.refStart,
      refEnd: m.refEnd,
      refAllele: m.refAllele,
      altAllele: m.altAllele,
      type: m.type,
      isTransition: m.isTransition,
      impact: impact,
    );
  }

  /// Convenience: per-site BLOSUM/PAM-aware severity score for a missense
  /// substitution's amino-acid change (negative = more disruptive), useful
  /// for sorting/highlighting the most impactful missense mutations first.
  static int missenseSeverity(MutationRecord m) {
    if (m.refAminoAcid == null || m.altAminoAcid == null) return 0;
    return SubstitutionMatrices.blosum62(m.refAminoAcid!, m.altAminoAcid!);
  }
}
