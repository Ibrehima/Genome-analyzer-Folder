import '../models/bio_sequence.dart';
import '../models/analysis_models.dart';
import 'sequence_engine.dart';

/// FastQC-style sequence quality assessment engine.
class QualityEngine {
  static QualityReport analyze(BioSequence seq) {
    final s = seq.sequence;
    final gc = SequenceEngine.gcContent(s);
    final at = SequenceEngine.atContent(s);
    final nCount = s.split('').where((c) => c == 'N').length;
    final nPct = s.isEmpty ? 0.0 : nCount / s.length * 100;
    final composition = SequenceEngine.baseComposition(s);

    double meanQ = -1, minQ = -1, maxQ = -1, q20 = -1, q30 = -1;
    final Map<int, double> perPositionBin = {};

    if (seq.hasQuality) {
      final q = seq.qualityScores!;
      meanQ = q.reduce((a, b) => a + b) / q.length;
      minQ = q.reduce((a, b) => a < b ? a : b).toDouble();
      maxQ = q.reduce((a, b) => a > b ? a : b).toDouble();
      q20 = q.where((v) => v >= 20).length / q.length * 100;
      q30 = q.where((v) => v >= 30).length / q.length * 100;

      // Bin into up to 20 bins across length for trend visualization
      const bins = 20;
      final binSize = (q.length / bins).ceil().clamp(1, q.length);
      for (int b = 0; b * binSize < q.length; b++) {
        final start = b * binSize;
        final end = (start + binSize).clamp(0, q.length);
        final slice = q.sublist(start, end);
        if (slice.isNotEmpty) {
          perPositionBin[b] = slice.reduce((a, b2) => a + b2) / slice.length;
        }
      }
    }

    String grade;
    if (seq.hasQuality) {
      if (meanQ >= 30 && nPct < 1) {
        grade = 'A';
      } else if (meanQ >= 20 && nPct < 5) {
        grade = 'B';
      } else if (meanQ >= 15) {
        grade = 'C';
      } else {
        grade = 'D';
      }
    } else {
      // Grade based on N-content and length for FASTA-only sequences
      if (nPct < 0.5 && seq.length > 50) {
        grade = 'A';
      } else if (nPct < 2) {
        grade = 'B';
      } else if (nPct < 5) {
        grade = 'C';
      } else {
        grade = 'D';
      }
    }

    return QualityReport(
      sequenceId: seq.id,
      sequenceName: seq.name,
      length: seq.length,
      gcContent: gc,
      atContent: at,
      nCount: nCount,
      nPercent: nPct,
      meanQuality: meanQ,
      minQuality: minQ,
      maxQuality: maxQ,
      qualityPerPositionBin: perPositionBin,
      baseComposition: composition,
      q20Percent: q20,
      q30Percent: q30,
      overallGrade: grade,
    );
  }

  static List<QualityReport> analyzeBatch(List<BioSequence> sequences) {
    return sequences.map(analyze).toList();
  }
}
