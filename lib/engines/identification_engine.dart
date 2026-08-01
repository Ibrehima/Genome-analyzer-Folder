import '../models/analysis_models.dart';
import '../data/reference_database.dart';
import 'sequence_engine.dart';

/// Species / lineage / variant identification engine using k-mer similarity
/// against the local curated reference database (BLAST-like heuristic).
class IdentificationEngine {
  static List<SpeciesMatch> identify(
    String querySequence, {
    int k = 6,
    int topN = 10,
  }) {
    final querySet = SequenceEngine.kmerSet(querySequence, k);
    final List<SpeciesMatch> matches = [];

    for (final ref in ReferenceDatabase.records) {
      final refSet = SequenceEngine.kmerSet(ref.sequence, k);
      if (querySet.isEmpty || refSet.isEmpty) continue;
      final shared = querySet.intersection(refSet).length;
      final union = querySet.union(refSet).length;
      final similarity = union == 0 ? 0.0 : shared / union * 100;
      matches.add(
        SpeciesMatch(
          reference: ref,
          similarityPercent: similarity,
          sharedKmers: shared,
          totalKmers: union,
        ),
      );
    }

    matches.sort((a, b) => b.similarityPercent.compareTo(a.similarityPercent));
    return matches.take(topN).toList();
  }

  /// Given the best match, extract lineage levels as a list.
  static List<String> lineageLevels(ReferenceRecord ref) {
    return ref.lineage.split(';');
  }

  /// Provides a confidence label based on similarity score.
  static String confidenceLabel(double similarityPercent) {
    if (similarityPercent >= 70) return 'High confidence';
    if (similarityPercent >= 40) return 'Moderate confidence';
    if (similarityPercent >= 15) return 'Low confidence';
    return 'Very low confidence — no reliable match';
  }

  /// Maps a single reference record to a broad domain-of-life / origin
  /// label (Human / Animal / Plant / Fungal / Bacterial / Viral /
  /// Archaeal / Protist / Unknown) based on its curated lineage string.
  static String domainLabel(ReferenceRecord ref) {
    final levels = lineageLevels(ref);
    if (levels.isEmpty) return 'Unknown';
    final domain = levels[0];
    if (ref.scientificName.trim().toLowerCase() == 'homo sapiens') {
      return 'Human';
    }
    switch (domain) {
      case 'Bacteria':
        return 'Bacterial';
      case 'Archaea':
        return 'Archaeal';
      case 'Viruses':
        return 'Viral';
      case 'Eukaryota':
        if (levels.length < 2) return 'Eukaryotic (other)';
        switch (levels[1]) {
          case 'Animalia':
            return 'Animal';
          case 'Plantae':
            return 'Plant';
          case 'Fungi':
            return 'Fungal';
          case 'Protista':
            return 'Protist (single-celled eukaryote)';
          default:
            return 'Eukaryotic (other)';
        }
      default:
        return 'Unknown';
    }
  }

  /// Classifies the biological origin (domain of life / broad group) of a
  /// query sequence by taking the top-ranked k-mer similarity match against
  /// the curated reference database and translating its lineage into a
  /// broad label. Confidence directly reflects the underlying k-mer
  /// similarity score of the best match — this is an identification-driven
  /// heuristic, not an independent domain classifier.
  static DomainClassificationResult classifyDomain(
    String querySequence, {
    int k = 6,
  }) {
    final matches = identify(querySequence, k: k, topN: 1);
    if (matches.isEmpty) {
      return DomainClassificationResult(
        domainLabel: 'Unknown',
        confidence: 0,
        basis:
            'No reference match could be computed (empty or invalid query sequence).',
      );
    }
    final best = matches.first;
    final label = domainLabel(best.reference);
    return DomainClassificationResult(
      domainLabel: label,
      confidence: best.similarityPercent,
      basis:
          'Best k-mer match: ${best.reference.scientificName} '
          '(${best.reference.markerGene}), ${best.similarityPercent.toStringAsFixed(1)}% '
          'k-mer similarity — ${confidenceLabel(best.similarityPercent).toLowerCase()}.',
      bestReference: best.reference,
    );
  }
}
