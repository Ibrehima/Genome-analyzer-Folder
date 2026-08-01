import 'dart:math';
import '../models/bio_sequence.dart';
import '../models/analysis_models.dart';
import 'sequence_engine.dart';

/// Statistical calculations across a collection of sequences.
class StatisticsEngine {
  static DescriptiveStats _describe(List<double> values) {
    if (values.isEmpty) {
      return DescriptiveStats(
        mean: 0,
        median: 0,
        stdDev: 0,
        min: 0,
        max: 0,
        n: 0,
      );
    }
    final n = values.length;
    final mean = values.reduce((a, b) => a + b) / n;
    final sorted = List<double>.from(values)..sort();
    final median = n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / n;
    final stdDev = sqrt(variance);
    return DescriptiveStats(
      mean: mean,
      median: median,
      stdDev: stdDev,
      min: sorted.first,
      max: sorted.last,
      n: n,
    );
  }

  /// Shannon diversity index (H') based on nucleotide/AA frequency.
  static double shannonIndex(Map<String, int> frequency) {
    final total = frequency.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return 0;
    double h = 0;
    frequency.forEach((_, count) {
      if (count > 0) {
        final p = count / total;
        h -= p * (log(p) / log(2));
      }
    });
    return h;
  }

  /// Simpson diversity index (1 - sum(p_i^2))
  static double simpsonIndex(Map<String, int> frequency) {
    final total = frequency.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return 0;
    double sumSq = 0;
    frequency.forEach((_, count) {
      final p = count / total;
      sumSq += p * p;
    });
    return 1 - sumSq;
  }

  static StatisticsReport analyzeCollection(List<BioSequence> sequences) {
    final lengths = sequences.map((s) => s.length.toDouble()).toList();
    final gcValues = sequences
        .map((s) => SequenceEngine.gcContent(s.sequence))
        .toList();

    final Map<String, int> combinedFreq = {};
    for (final s in sequences) {
      final comp = SequenceEngine.baseComposition(s.sequence);
      comp.forEach((k, v) {
        combinedFreq[k] = (combinedFreq[k] ?? 0) + v;
      });
    }

    return StatisticsReport(
      lengthStats: _describe(lengths),
      gcStats: _describe(gcValues),
      shannonDiversityIndex: shannonIndex(combinedFreq),
      simpsonDiversityIndex: simpsonIndex(combinedFreq),
      nucleotideFrequency: combinedFreq,
      totalSequences: sequences.length,
    );
  }

  /// Detects simple SNP variants between a query and reference sequence
  /// (assumes roughly equal length / pre-aligned).
  static List<VariantCall> callVariants(String reference, String query) {
    final List<VariantCall> variants = [];
    final len = min(reference.length, query.length);
    for (int i = 0; i < len; i++) {
      if (reference[i] != query[i]) {
        variants.add(
          VariantCall(
            position: i,
            refBase: reference[i],
            altBase: query[i],
            type: (reference[i] == '-' || query[i] == '-') ? 'Indel' : 'SNP',
          ),
        );
      }
    }
    if (query.length > reference.length) {
      for (int i = reference.length; i < query.length; i++) {
        variants.add(
          VariantCall(
            position: i,
            refBase: '-',
            altBase: query[i],
            type: 'Insertion',
          ),
        );
      }
    } else if (reference.length > query.length) {
      for (int i = query.length; i < reference.length; i++) {
        variants.add(
          VariantCall(
            position: i,
            refBase: reference[i],
            altBase: '-',
            type: 'Deletion',
          ),
        );
      }
    }
    return variants;
  }
}
