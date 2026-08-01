import '../models/analysis_models.dart';
import 'proteomics_engine.dart';

/// Heuristic therapeutic / vaccine molecular-target analysis for protein
/// sequences: hydrophilicity/surface-accessibility profiling, transmembrane
/// segment prediction, and linear B-cell epitope / vaccine-target candidate
/// ranking.
///
/// HONESTY NOTE: this uses classic, published propensity SCALES (Parker et
/// al. 1986 hydrophilicity; Kyte & Doolittle 1982 hydropathy for TM
/// prediction) combined with simple sliding-window heuristics. It is NOT
/// equivalent to validated epitope-prediction servers (e.g. IEDB, BepiPred,
/// NetMHC) or to experimentally-confirmed antigenicity/immunogenicity data.
/// Results should be treated as exploratory triage candidates only, always
/// requiring wet-lab / immunoinformatics-tool confirmation before any
/// therapeutic or vaccine-design use.
class TargetAnalysisEngine {
  // Parker, Guo & Hodges (1986) hydrophilicity scale.
  static const Map<String, double> _parker = {
    'A': 2.1,
    'R': 4.2,
    'N': 7.0,
    'D': 10.0,
    'C': 1.4,
    'Q': 6.0,
    'E': 7.8,
    'G': 5.7,
    'H': 2.1,
    'I': -8.0,
    'L': -9.2,
    'K': 5.7,
    'M': -4.2,
    'F': -9.2,
    'P': 2.1,
    'S': 6.5,
    'T': 5.2,
    'W': -10.0,
    'Y': -1.9,
    'V': -3.7,
  };

  // Kyte & Doolittle (1982) hydropathy scale — reused here for the classic
  // "sliding-window mean > ~1.6" transmembrane-helix heuristic.
  static const Map<String, double> _kyteDoolittle = {
    'A': 1.8,
    'R': -4.5,
    'N': -3.5,
    'D': -3.5,
    'C': 2.5,
    'Q': -3.5,
    'E': -3.5,
    'G': -0.4,
    'H': -3.2,
    'I': 4.5,
    'L': 3.8,
    'K': -3.9,
    'M': 1.9,
    'F': 2.8,
    'P': -1.6,
    'S': -0.8,
    'T': -0.7,
    'W': -0.9,
    'Y': -1.3,
    'V': 4.2,
  };

  static const double _parkerMin = -10.0;
  static const double _parkerMax = 10.0;

  /// Per-residue windowed average hydrophilicity (Parker scale), centered
  /// window of size [window] (odd number recommended).
  static List<double> hydrophilicityProfile(String protein, {int window = 7}) {
    final n = protein.length;
    final half = window ~/ 2;
    final profile = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final start = (i - half).clamp(0, n - 1);
      final end = (i + half).clamp(0, n - 1);
      double sum = 0;
      int count = 0;
      for (int j = start; j <= end; j++) {
        sum += _parker[protein[j]] ?? 0;
        count++;
      }
      profile[i] = count > 0 ? sum / count : 0;
    }
    return profile;
  }

  /// Sliding-window Kyte-Doolittle mean hydropathy scan to flag likely
  /// transmembrane helices (classic rule-of-thumb: ~19-21 residue window,
  /// mean hydropathy above ~1.6 suggests a membrane-spanning alpha helix).
  static List<TransmembraneRegion> predictTransmembraneRegions(
    String protein, {
    int window = 19,
    double threshold = 1.6,
  }) {
    final n = protein.length;
    if (n < window) return [];
    final flags = List<bool>.filled(n, false);
    final windowMeans = List<double>.filled(n, 0);
    for (int i = 0; i <= n - window; i++) {
      double sum = 0;
      for (int j = i; j < i + window; j++) {
        sum += _kyteDoolittle[protein[j]] ?? 0;
      }
      final mean = sum / window;
      final center = i + window ~/ 2;
      windowMeans[center] = mean;
      if (mean >= threshold) {
        for (int j = i; j < i + window; j++) {
          flags[j] = true;
        }
      }
    }

    final regions = <TransmembraneRegion>[];
    int? regionStart;
    for (int i = 0; i < n; i++) {
      if (flags[i] && regionStart == null) {
        regionStart = i;
      } else if (!flags[i] && regionStart != null) {
        regions.add(_makeRegion(protein, regionStart, i));
        regionStart = null;
      }
    }
    if (regionStart != null) {
      regions.add(_makeRegion(protein, regionStart, n));
    }
    return regions;
  }

  static TransmembraneRegion _makeRegion(String protein, int start, int end) {
    double sum = 0;
    for (int i = start; i < end; i++) {
      sum += _kyteDoolittle[protein[i]] ?? 0;
    }
    return TransmembraneRegion(
      start: start,
      end: end,
      meanHydrophobicity: sum / (end - start),
    );
  }

  static bool _overlapsAny(
    int start,
    int end,
    List<TransmembraneRegion> regions,
  ) {
    for (final r in regions) {
      if (start < r.end && end > r.start) return true;
    }
    return false;
  }

  /// Scans overlapping windows of [peptideLength] residues (default 9,
  /// a common linear B-cell / MHC-I-adjacent epitope length used in
  /// screening pipelines) and scores each by normalized mean Parker
  /// hydrophilicity as a proxy for surface accessibility / antigenicity.
  static List<EpitopeCandidate> predictEpitopes(
    String protein, {
    int peptideLength = 9,
    double minScore = 55,
    List<TransmembraneRegion> tmRegions = const [],
  }) {
    final n = protein.length;
    final candidates = <EpitopeCandidate>[];
    if (n < peptideLength) return candidates;
    for (int i = 0; i <= n - peptideLength; i++) {
      final end = i + peptideLength;
      double sum = 0;
      for (int j = i; j < end; j++) {
        sum += _parker[protein[j]] ?? 0;
      }
      final mean = sum / peptideLength;
      final score = (((mean - _parkerMin) / (_parkerMax - _parkerMin)) * 100)
          .clamp(0, 100)
          .toDouble();
      if (score >= minScore) {
        final surfaceExposed = !_overlapsAny(i, end, tmRegions) && mean > 0;
        candidates.add(
          EpitopeCandidate(
            start: i,
            end: end,
            peptide: protein.substring(i, end),
            antigenicityScore: score,
            surfaceExposed: surfaceExposed,
          ),
        );
      }
    }
    // Keep only local maxima-ish by removing heavily overlapping lower-score
    // windows: greedy non-max suppression sorted by score desc.
    candidates.sort(
      (a, b) => b.antigenicityScore.compareTo(a.antigenicityScore),
    );
    final kept = <EpitopeCandidate>[];
    for (final c in candidates) {
      final overlaps = kept.any((k) => c.start < k.end && c.end > k.start);
      if (!overlaps) kept.add(c);
    }
    kept.sort((a, b) => a.start.compareTo(b.start));
    return kept;
  }

  /// Ranks candidate epitopes as vaccine-target candidates: prioritizes
  /// surface-exposed, high-antigenicity, non-transmembrane peptides.
  static List<EpitopeCandidate> rankVaccineTargets(
    List<EpitopeCandidate> candidates, {
    int topN = 8,
  }) {
    final surfaceOnes = candidates.where((c) => c.surfaceExposed).toList()
      ..sort((a, b) => b.antigenicityScore.compareTo(a.antigenicityScore));
    return surfaceOnes.take(topN).toList();
  }

  static TargetAnalysisResult analyze(String rawProtein) {
    final protein = ProteomicsEngine.cleanProtein(rawProtein);
    final hydro = hydrophilicityProfile(protein);
    final tm = predictTransmembraneRegions(protein);
    final epitopes = predictEpitopes(protein, tmRegions: tm);
    final vaccineTargets = rankVaccineTargets(epitopes);

    return TargetAnalysisResult(
      hydrophilicityProfile: hydro,
      transmembraneRegions: tm,
      candidateEpitopes: epitopes,
      vaccineTargetCandidates: vaccineTargets,
      disclaimer:
          'Heuristic triage only (Parker hydrophilicity + Kyte-Doolittle '
          'transmembrane rule-of-thumb). NOT a validated epitope-prediction '
          'or immunogenicity-prediction tool — confirm any candidate with '
          'dedicated immunoinformatics tools (e.g. IEDB, BepiPred, NetMHC) '
          'and experimental assays before therapeutic or vaccine use.',
    );
  }
}
