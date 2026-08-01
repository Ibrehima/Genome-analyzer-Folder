import '../data/metabolite_database.dart';
import '../models/analysis_models.dart';

/// Offline metabolomics triage: chemical-formula mass calculation (average
/// + monoisotopic, using standard IUPAC atomic weights / monoisotopic
/// masses) and lookup/mass-based search against a small curated local
/// metabolite database.
///
/// HONESTY NOTE: this is NOT a substitute for MS/NMR-based metabolite
/// identification pipelines, nor for authoritative databases (KEGG, HMDB,
/// PubChem, MetaboAnalyst). The formula-mass math itself uses real,
/// standard physical constants (atomic weights / monoisotopic masses) so
/// it is exact for the formula entered; the curated database is a small
/// (32-metabolite) demonstration set covering common central-carbon,
/// nitrogen and lipid metabolism metabolites only.
class MetabolomicsEngine {
  // IUPAC standard atomic weights (average, Da) for common elements found
  // in biological metabolites.
  static const Map<String, double> _avgAtomicWeight = {
    'H': 1.008,
    'C': 12.011,
    'N': 14.007,
    'O': 15.999,
    'P': 30.974,
    'S': 32.06,
    'Na': 22.990,
    'K': 39.098,
    'Ca': 40.078,
    'Mg': 24.305,
    'Cl': 35.45,
    'F': 18.998,
    'Br': 79.904,
    'I': 126.904,
    'Fe': 55.845,
  };

  // Monoisotopic masses (Da) of the most abundant isotope — the standard
  // reference values used in mass-spectrometry-based identification.
  static const Map<String, double> _monoAtomicMass = {
    'H': 1.0078250319,
    'C': 12.0000000,
    'N': 14.0030740052,
    'O': 15.9949146221,
    'P': 30.97376151,
    'S': 31.97207069,
    'Na': 22.98976928,
    'K': 38.9637069,
    'Ca': 39.9625912,
    'Mg': 23.9850417,
    'Cl': 34.96885268,
    'F': 18.99840322,
    'Br': 78.9183376,
    'I': 126.9044719,
    'Fe': 55.9349421,
  };

  // Common ionization adducts (mass shift, Da) used in mass-spec triage.
  static const Map<String, double> _adductShift = {
    'M (neutral)': 0.0,
    '[M+H]+': 1.007276,
    '[M-H]-': -1.007276,
    '[M+Na]+': 22.98922,
    '[M+K]+': 38.96316,
  };

  static List<String> get supportedAdducts => _adductShift.keys.toList();

  /// Parses a simple chemical formula (e.g. "C6H12O6", "C10H16N5O13P3") —
  /// no nested parentheses/brackets support, sufficient for the small
  /// metabolites used in this module.
  static Map<String, int> parseFormula(String formula) {
    final clean = formula.trim();
    final regex = RegExp(r'([A-Z][a-z]?)(\d*)');
    final counts = <String, int>{};
    for (final match in regex.allMatches(clean)) {
      final element = match.group(1);
      if (element == null || element.isEmpty) continue;
      final countStr = match.group(2);
      final count = (countStr == null || countStr.isEmpty)
          ? 1
          : int.parse(countStr);
      counts[element] = (counts[element] ?? 0) + count;
    }
    return counts;
  }

  /// Computes average and monoisotopic molecular mass from a formula
  /// string using standard atomic-weight tables. Unrecognized element
  /// symbols are ignored (with counts still returned for transparency).
  static FormulaMassResult computeMass(String formula) {
    final counts = parseFormula(formula);
    double avg = 0;
    double mono = 0;
    counts.forEach((el, n) {
      avg += (_avgAtomicWeight[el] ?? 0) * n;
      mono += (_monoAtomicMass[el] ?? 0) * n;
    });
    return FormulaMassResult(
      formula: formula.trim(),
      elementCounts: counts,
      averageMassDa: avg,
      monoisotopicMassDa: mono,
    );
  }

  /// Returns true if every element symbol in [formula] is recognized.
  static bool isFormulaFullyRecognized(String formula) {
    final counts = parseFormula(formula);
    if (counts.isEmpty) return false;
    return counts.keys.every((el) => _avgAtomicWeight.containsKey(el));
  }

  /// Simple case-insensitive substring search over name / class / pathway.
  static List<MetaboliteRecord> search(String query) {
    if (query.trim().isEmpty) return MetaboliteDatabase.records;
    final q = query.trim().toLowerCase();
    return MetaboliteDatabase.records
        .where(
          (m) =>
              m.name.toLowerCase().contains(q) ||
              m.metaboliteClass.toLowerCase().contains(q) ||
              m.pathway.toLowerCase().contains(q) ||
              m.formula.toLowerCase().contains(q),
        )
        .toList();
  }

  static List<String> allClasses() =>
      MetaboliteDatabase.records.map((m) => m.metaboliteClass).toSet().toList()
        ..sort();

  static List<String> allPathways() =>
      MetaboliteDatabase.records.map((m) => m.pathway).toSet().toList()..sort();

  /// Mass-based ("MS-style") identification: given an observed mass, an
  /// ionization adduct and a tolerance (ppm), ranks curated-database
  /// metabolites whose theoretical adduct mass falls within tolerance.
  /// Classic small-molecule ID triage — NOT a substitute for MS/MS
  /// fragmentation or retention-time confirmation.
  static List<MassSearchMatch> searchByMass(
    double observedMass, {
    String adduct = '[M+H]+',
    double tolerancePpm = 20,
  }) {
    final shift = _adductShift[adduct] ?? 0.0;
    final matches = <MassSearchMatch>[];
    for (final m in MetaboliteDatabase.records) {
      final neutralMono = computeMass(m.formula).monoisotopicMassDa;
      final theoretical = neutralMono + shift;
      if (theoretical <= 0) continue;
      final deltaPpm = (observedMass - theoretical) / theoretical * 1e6;
      if (deltaPpm.abs() <= tolerancePpm) {
        matches.add(
          MassSearchMatch(
            metabolite: m,
            theoreticalMass: theoretical,
            deltaPpm: deltaPpm,
            adduct: adduct,
          ),
        );
      }
    }
    matches.sort((a, b) => a.deltaPpm.abs().compareTo(b.deltaPpm.abs()));
    return matches;
  }
}
