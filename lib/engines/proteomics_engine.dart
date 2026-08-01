import 'dart:math';
import '../models/analysis_models.dart';

/// Proteomics / physicochemical property calculations, modeled after the
/// classic ExPASy ProtParam metrics (molecular weight, theoretical pI,
/// GRAVY hydrophobicity, aliphatic index, extinction coefficient) plus a
/// simplified Chou-Fasman-style secondary-structure propensity estimate.
///
/// HONESTY NOTE: pI uses an approximate Bjellqvist-style pKa set (a
/// commonly used simplified reference, not a fitted/validated model);
/// secondary-structure propensity uses the classic 1978 Chou-Fasman scale
/// (indicative only — for real predictions use validated tools such as
/// PSIPRED / AlphaFold).
class ProteomicsEngine {
  // Average residue masses (Da), i.e. amino acid mass minus water.
  static const Map<String, double> _residueMass = {
    'G': 57.0519,
    'A': 71.0788,
    'S': 87.0782,
    'P': 97.1167,
    'V': 99.1326,
    'T': 101.1051,
    'C': 103.1388,
    'L': 113.1594,
    'I': 113.1594,
    'N': 114.1038,
    'D': 115.0886,
    'Q': 128.1307,
    'K': 128.1741,
    'E': 129.1155,
    'M': 131.1926,
    'H': 137.1411,
    'F': 147.1766,
    'R': 156.1875,
    'Y': 163.1760,
    'W': 186.2132,
  };

  static const double _waterMass = 18.01524;

  // Kyte & Doolittle (1982) hydropathy scale.
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

  // Chou-Fasman (1978) conformational propensities: [helix, sheet, turn]
  static const Map<String, List<double>> _chouFasman = {
    'A': [1.42, 0.83, 0.66],
    'R': [0.98, 0.93, 0.95],
    'N': [0.67, 0.89, 1.56],
    'D': [1.01, 0.54, 1.46],
    'C': [0.70, 1.19, 1.19],
    'Q': [1.11, 1.10, 0.98],
    'E': [1.51, 0.37, 0.74],
    'G': [0.57, 0.75, 1.56],
    'H': [1.00, 0.87, 0.95],
    'I': [1.08, 1.60, 0.47],
    'L': [1.21, 1.30, 0.59],
    'K': [1.16, 0.74, 1.01],
    'M': [1.45, 1.05, 0.60],
    'F': [1.13, 1.38, 0.60],
    'P': [0.57, 0.55, 1.52],
    'S': [0.77, 0.75, 1.43],
    'T': [0.83, 1.19, 0.96],
    'W': [1.08, 1.37, 0.96],
    'Y': [0.69, 1.47, 1.14],
    'V': [1.06, 1.70, 0.50],
  };

  /// Cleans a protein sequence: uppercase, removes stop codon '*' and any
  /// non-standard-amino-acid characters.
  static String cleanProtein(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'[^ACDEFGHIKLMNPQRSTVWY]'), '');
  }

  static Map<String, int> aminoAcidComposition(String protein) {
    final Map<String, int> comp = {};
    for (final c in protein.split('')) {
      comp[c] = (comp[c] ?? 0) + 1;
    }
    return comp;
  }

  static double molecularWeight(String protein) {
    if (protein.isEmpty) return 0;
    double sum = _waterMass;
    for (final c in protein.split('')) {
      sum += _residueMass[c] ?? 110.0; // fallback average if unknown
    }
    return sum;
  }

  static double gravyScore(String protein) {
    if (protein.isEmpty) return 0;
    double sum = 0;
    for (final c in protein.split('')) {
      sum += _kyteDoolittle[c] ?? 0;
    }
    return sum / protein.length;
  }

  static double aliphaticIndex(String protein) {
    if (protein.isEmpty) return 0;
    final comp = aminoAcidComposition(protein);
    final n = protein.length;
    double pct(String aa) => (comp[aa] ?? 0) / n * 100;
    return pct('A') + 2.9 * pct('V') + 3.9 * (pct('I') + pct('L'));
  }

  static double extinctionCoefficient280(String protein) {
    final comp = aminoAcidComposition(protein);
    final nTrp = comp['W'] ?? 0;
    final nTyr = comp['Y'] ?? 0;
    final nCys = comp['C'] ?? 0;
    final nCystine = (nCys / 2).floor(); // approx: assumes paired disulfides
    return nTrp * 5500.0 + nTyr * 1490.0 + nCystine * 125.0;
  }

  /// Approximate theoretical isoelectric point via bisection on net charge,
  /// using a Bjellqvist-style simplified pKa set.
  static double isoelectricPoint(String protein) {
    if (protein.isEmpty) return 7.0;
    final comp = aminoAcidComposition(protein);
    const nTermPka = 7.5;
    const cTermPka = 3.55;
    const posPka = {'K': 10.0, 'R': 12.0, 'H': 5.98};
    const negPka = {'D': 4.05, 'E': 4.45, 'C': 9.0, 'Y': 10.0};

    double chargeAt(double pH) {
      double charge = 1 / (1 + pow(10, pH - nTermPka));
      charge -= 1 / (1 + pow(10, cTermPka - pH));
      posPka.forEach((aa, pka) {
        final n = comp[aa] ?? 0;
        if (n > 0) charge += n * (1 / (1 + pow(10, pH - pka)));
      });
      negPka.forEach((aa, pka) {
        final n = comp[aa] ?? 0;
        if (n > 0) charge -= n * (1 / (1 + pow(10, pka - pH)));
      });
      return charge;
    }

    double lo = 0, hi = 14;
    for (int i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (chargeAt(mid) > 0) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// Average Chou-Fasman propensity across the whole protein for
  /// [helix, sheet, turn] — indicative conformational tendency only.
  static Map<String, double> secondaryStructurePropensity(String protein) {
    if (protein.isEmpty) return {'Helix': 1, 'Sheet': 1, 'Turn': 1};
    double h = 0, s = 0, t = 0;
    for (final c in protein.split('')) {
      final v = _chouFasman[c];
      if (v != null) {
        h += v[0];
        s += v[1];
        t += v[2];
      }
    }
    final n = protein.length;
    return {'Helix': h / n, 'Sheet': s / n, 'Turn': t / n};
  }

  /// Per-residue secondary-structure class guess (Helix/Sheet/Coil) based
  /// on which Chou-Fasman propensity is highest at each position, with a
  /// simple 5-residue majority-vote smoothing pass. Indicative only.
  static List<String> perResidueSecondaryStructure(String protein) {
    final raw = <String>[];
    for (final c in protein.split('')) {
      final v = _chouFasman[c] ?? [1, 1, 1];
      if (v[0] >= v[1] && v[0] >= v[2]) {
        raw.add('Helix');
      } else if (v[1] >= v[0] && v[1] >= v[2]) {
        raw.add('Sheet');
      } else {
        raw.add('Coil');
      }
    }
    final smoothed = List<String>.from(raw);
    for (int i = 0; i < raw.length; i++) {
      final start = (i - 2).clamp(0, raw.length - 1);
      final end = (i + 2).clamp(0, raw.length - 1);
      final counts = <String, int>{};
      for (int j = start; j <= end; j++) {
        counts[raw[j]] = (counts[raw[j]] ?? 0) + 1;
      }
      smoothed[i] = counts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }
    return smoothed;
  }

  static ProteinPropertiesResult analyze(String rawProtein) {
    final protein = cleanProtein(rawProtein);
    final comp = aminoAcidComposition(protein);
    return ProteinPropertiesResult(
      proteinSequence: protein,
      molecularWeightDa: molecularWeight(protein),
      isoelectricPoint: isoelectricPoint(protein),
      gravyScore: gravyScore(protein),
      aliphaticIndex: aliphaticIndex(protein),
      extinctionCoefficient280: extinctionCoefficient280(protein),
      aminoAcidComposition: comp,
      secondaryStructurePropensity: secondaryStructurePropensity(protein),
      numCysteines: comp['C'] ?? 0,
      numTryptophans: comp['W'] ?? 0,
      numTyrosines: comp['Y'] ?? 0,
    );
  }
}
