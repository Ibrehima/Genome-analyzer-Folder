/// Standard protein substitution matrices (BLOSUM62, PAM250) plus DNA
/// transition/transversion-aware scoring, used by [AlignmentEngine].
///
/// Matrix values are the well-known published tables (NCBI BLOSUM62 / PAM250).
/// Unknown residues fall back to a small negative score so the aligner never
/// crashes on ambiguity codes (N, X, B, Z, *...).
library;

class SubstitutionMatrices {
  static const String _aa = 'ARNDCQEGHILKMFPSTWYV';

  // BLOSUM62, order matches `_aa` above (NCBI standard matrix).
  static const List<List<int>> _blosum62 = [
    [4, -1, -2, -2, 0, -1, -1, 0, -2, -1, -1, -1, -1, -2, -1, 1, 0, -3, -2, 0],
    [-1, 5, 0, -2, -3, 1, 0, -2, 0, -3, -2, 2, -1, -3, -2, -1, -1, -3, -2, -3],
    [-2, 0, 6, 1, -3, 0, 0, 0, 1, -3, -3, 0, -2, -3, -2, 1, 0, -4, -2, -3],
    [-2, -2, 1, 6, -3, 0, 2, -1, -1, -3, -4, -1, -3, -3, -1, 0, -1, -4, -3, -3],
    [
      0,
      -3,
      -3,
      -3,
      9,
      -3,
      -4,
      -3,
      -3,
      -1,
      -1,
      -3,
      -1,
      -2,
      -3,
      -1,
      -1,
      -2,
      -2,
      -1,
    ],
    [-1, 1, 0, 0, -3, 5, 2, -2, 0, -3, -2, 1, 0, -3, -1, 0, -1, -2, -1, -2],
    [-1, 0, 0, 2, -4, 2, 5, -2, 0, -3, -3, 1, -2, -3, -1, 0, -1, -3, -2, -2],
    [
      0,
      -2,
      0,
      -1,
      -3,
      -2,
      -2,
      6,
      -2,
      -4,
      -4,
      -2,
      -3,
      -3,
      -2,
      0,
      -2,
      -2,
      -3,
      -3,
    ],
    [-2, 0, 1, -1, -3, 0, 0, -2, 8, -3, -3, -1, -2, -1, -2, -1, -2, -2, 2, -3],
    [-1, -3, -3, -3, -1, -3, -3, -4, -3, 4, 2, -3, 1, 0, -3, -2, -1, -3, -1, 3],
    [-1, -2, -3, -4, -1, -2, -3, -4, -3, 2, 4, -2, 2, 0, -3, -2, -1, -2, -1, 1],
    [-1, 2, 0, -1, -3, 1, 1, -2, -1, -3, -2, 5, -1, -3, -1, 0, -1, -3, -2, -2],
    [-1, -1, -2, -3, -1, 0, -2, -3, -2, 1, 2, -1, 5, 0, -2, -1, -1, -1, -1, 1],
    [-2, -3, -3, -3, -2, -3, -3, -3, -1, 0, 0, -3, 0, 6, -4, -2, -2, 1, 3, -1],
    [
      -1,
      -2,
      -2,
      -1,
      -3,
      -1,
      -1,
      -2,
      -2,
      -3,
      -3,
      -1,
      -2,
      -4,
      7,
      -1,
      -1,
      -4,
      -3,
      -2,
    ],
    [1, -1, 1, 0, -1, 0, 0, 0, -1, -2, -2, 0, -1, -2, -1, 4, 1, -3, -2, -2],
    [0, -1, 0, -1, -1, -1, -1, -2, -2, -1, -1, -1, -1, -2, -1, 1, 5, -2, -2, 0],
    [
      -3,
      -3,
      -4,
      -4,
      -2,
      -2,
      -3,
      -2,
      -2,
      -3,
      -2,
      -3,
      -1,
      1,
      -4,
      -3,
      -2,
      11,
      2,
      -3,
    ],
    [
      -2,
      -2,
      -2,
      -3,
      -2,
      -1,
      -2,
      -3,
      2,
      -1,
      -1,
      -2,
      -1,
      3,
      -3,
      -2,
      -2,
      2,
      7,
      -1,
    ],
    [0, -3, -3, -3, -1, -2, -2, -3, -3, 3, 1, -2, 1, -1, -2, -2, 0, -3, -1, 4],
  ];

  // PAM250, order matches `_aa` above (NCBI standard matrix).
  static const List<List<int>> _pam250 = [
    [2, -2, 0, 0, -2, 0, 0, 1, -1, -1, -2, -1, -1, -3, 1, 1, 1, -6, -3, 0],
    [-2, 6, 0, -1, -4, 1, -1, -3, 2, -2, -3, 3, 0, -4, 0, 0, -1, 2, -4, -2],
    [0, 0, 2, 2, -4, 1, 1, 0, 2, -2, -3, 1, -2, -3, 0, 1, 0, -4, -2, -2],
    [0, -1, 2, 4, -5, 2, 3, 1, 1, -2, -4, 0, -3, -6, -1, 0, 0, -7, -4, -2],
    [
      -2,
      -4,
      -4,
      -5,
      12,
      -5,
      -5,
      -3,
      -3,
      -2,
      -6,
      -5,
      -5,
      -4,
      -3,
      0,
      -2,
      -8,
      0,
      -2,
    ],
    [0, 1, 1, 2, -5, 4, 2, -1, 3, -2, -2, 1, -1, -5, 0, -1, -1, -5, -4, -2],
    [0, -1, 1, 3, -5, 2, 4, 0, 1, -2, -3, 0, -2, -5, -1, 0, 0, -7, -4, -2],
    [1, -3, 0, 1, -3, -1, 0, 5, -2, -3, -4, -2, -3, -5, 0, 1, 0, -7, -5, -1],
    [-1, 2, 2, 1, -3, 3, 1, -2, 6, -2, -2, 0, -2, -2, 0, -1, -1, -3, 0, -2],
    [-1, -2, -2, -2, -2, -2, -2, -3, -2, 5, 2, -2, 2, 1, -2, -1, 0, -5, -1, 4],
    [-2, -3, -3, -4, -6, -2, -3, -4, -2, 2, 6, -3, 4, 2, -3, -3, -2, -2, -1, 2],
    [-1, 3, 1, 0, -5, 1, 0, -2, 0, -2, -3, 5, 0, -5, -1, 0, 0, -3, -4, -2],
    [-1, 0, -2, -3, -5, -1, -2, -3, -2, 2, 4, 0, 6, 0, -2, -2, -1, -4, -2, 2],
    [-3, -4, -3, -6, -4, -5, -5, -5, -2, 1, 2, -5, 0, 9, -5, -3, -3, 0, 7, -1],
    [1, 0, 0, -1, -3, 0, -1, 0, 0, -2, -3, -1, -2, -5, 6, 1, 0, -6, -5, -1],
    [1, 0, 1, 0, 0, -1, 0, 1, -1, -1, -3, 0, -2, -3, 1, 2, 1, -2, -3, -1],
    [1, -1, 0, 0, -2, -1, 0, 0, -1, 0, -2, 0, -1, -3, 0, 1, 3, -5, -3, 0],
    [
      -6,
      2,
      -4,
      -7,
      -8,
      -5,
      -7,
      -7,
      -3,
      -5,
      -2,
      -3,
      -4,
      0,
      -6,
      -2,
      -5,
      17,
      0,
      -6,
    ],
    [
      -3,
      -4,
      -2,
      -4,
      0,
      -4,
      -4,
      -5,
      0,
      -1,
      -1,
      -4,
      -2,
      7,
      -5,
      -3,
      -3,
      0,
      10,
      -2,
    ],
    [0, -2, -2, -2, -2, -2, -2, -1, -2, 4, 2, -2, 2, -1, -1, -1, 0, -6, -2, 4],
  ];

  static final Map<String, int> _aaIndex = {
    for (int i = 0; i < _aa.length; i++) _aa[i]: i,
  };

  static int blosum62(String a, String b) {
    final ia = _aaIndex[a];
    final ib = _aaIndex[b];
    if (ia == null || ib == null) return a == b ? 1 : -1;
    return _blosum62[ia][ib];
  }

  static int pam250(String a, String b) {
    final ia = _aaIndex[a];
    final ib = _aaIndex[b];
    if (ia == null || ib == null) return a == b ? 1 : -1;
    return _pam250[ia][ib];
  }

  static const Set<String> _purines = {'A', 'G'};
  static const Set<String> _pyrimidines = {'C', 'T', 'U'};

  /// Transition (purine<->purine / pyrimidine<->pyrimidine) mismatches are
  /// biologically more common/less disruptive than transversions, so they
  /// get a milder penalty when this scheme is selected.
  static int dnaTransitionTransversion(
    String a,
    String b, {
    required int matchScore,
    required int mismatchScore,
    required int transitionPenalty,
  }) {
    if (a == b) return matchScore;
    final bothPurine = _purines.contains(a) && _purines.contains(b);
    final bothPyrimidine = _pyrimidines.contains(a) && _pyrimidines.contains(b);
    if (bothPurine || bothPyrimidine) {
      // Transition: milder than a full transversion mismatch.
      return transitionPenalty;
    }
    return mismatchScore;
  }
}
