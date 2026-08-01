import '../models/bio_sequence.dart';

/// Utilities for parsing and manipulating biological sequences.
class SequenceEngine {
  static const _codonTable = {
    'TTT': 'F',
    'TTC': 'F',
    'TTA': 'L',
    'TTG': 'L',
    'CTT': 'L',
    'CTC': 'L',
    'CTA': 'L',
    'CTG': 'L',
    'ATT': 'I',
    'ATC': 'I',
    'ATA': 'I',
    'ATG': 'M',
    'GTT': 'V',
    'GTC': 'V',
    'GTA': 'V',
    'GTG': 'V',
    'TCT': 'S',
    'TCC': 'S',
    'TCA': 'S',
    'TCG': 'S',
    'CCT': 'P',
    'CCC': 'P',
    'CCA': 'P',
    'CCG': 'P',
    'ACT': 'T',
    'ACC': 'T',
    'ACA': 'T',
    'ACG': 'T',
    'GCT': 'A',
    'GCC': 'A',
    'GCA': 'A',
    'GCG': 'A',
    'TAT': 'Y',
    'TAC': 'Y',
    'TAA': '*',
    'TAG': '*',
    'CAT': 'H',
    'CAC': 'H',
    'CAA': 'Q',
    'CAG': 'Q',
    'AAT': 'N',
    'AAC': 'N',
    'AAA': 'K',
    'AAG': 'K',
    'GAT': 'D',
    'GAC': 'D',
    'GAA': 'E',
    'GAG': 'E',
    'TGT': 'C',
    'TGC': 'C',
    'TGA': '*',
    'TGG': 'W',
    'CGT': 'R',
    'CGC': 'R',
    'CGA': 'R',
    'CGG': 'R',
    'AGT': 'S',
    'AGC': 'S',
    'AGA': 'R',
    'AGG': 'R',
    'GGT': 'G',
    'GGC': 'G',
    'GGA': 'G',
    'GGG': 'G',
  };

  /// Detects sequence type from raw letters.
  static SequenceType detectType(String seq) {
    final s = seq.toUpperCase();
    if (s.isEmpty) return SequenceType.unknown;
    final proteinOnly = RegExp(r'[EFILPQZ]');
    final dnaChars = RegExp(r'^[ACGTUN\-\s]+$');
    if (proteinOnly.hasMatch(s) && !dnaChars.hasMatch(s)) {
      return SequenceType.protein;
    }
    final uCount = s.split('').where((c) => c == 'U').length;
    final tCount = s.split('').where((c) => c == 'T').length;
    if (dnaChars.hasMatch(s)) {
      return uCount > tCount ? SequenceType.rna : SequenceType.dna;
    }
    return SequenceType.protein;
  }

  static String sanitize(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z\*\-]'), '');
  }

  /// Parses a multi-FASTA text block into BioSequence list.
  static List<BioSequence> parseFasta(
    String content, {
    String source = 'upload',
  }) {
    final List<BioSequence> results = [];
    final lines = content.split(RegExp(r'\r?\n'));
    String? currentHeader;
    StringBuffer buf = StringBuffer();

    void flush() {
      if (currentHeader != null && buf.isNotEmpty) {
        final seq = sanitize(buf.toString());
        if (seq.isNotEmpty) {
          final parts = currentHeader.split(RegExp(r'\s+'));
          final name = parts.isNotEmpty ? parts.first : 'seq';
          final desc = parts.length > 1 ? parts.sublist(1).join(' ') : '';
          results.add(
            BioSequence(
              name: name,
              description: desc,
              type: detectType(seq),
              sequence: seq,
              source: source,
            ),
          );
        }
      }
      buf = StringBuffer();
    }

    for (final line in lines) {
      if (line.startsWith('>')) {
        flush();
        currentHeader = line.substring(1).trim();
      } else {
        buf.write(line.trim());
      }
    }
    flush();
    return results;
  }

  /// Parses FASTQ (4-line records) content into BioSequence list with quality scores.
  static List<BioSequence> parseFastq(
    String content, {
    String source = 'upload',
  }) {
    final List<BioSequence> results = [];
    final lines = content
        .split(RegExp(r'\r?\n'))
        .where((l) => l.isNotEmpty)
        .toList();
    for (int i = 0; i + 3 < lines.length; i += 4) {
      final header = lines[i];
      if (!header.startsWith('@')) continue;
      final seqLine = lines[i + 1].trim();
      final qualLine = lines[i + 3].trim();
      final seq = sanitize(seqLine);
      final quality = qualLine
          .split('')
          .map((c) => c.codeUnitAt(0) - 33)
          .toList();
      final name = header.substring(1).split(RegExp(r'\s+')).first;
      results.add(
        BioSequence(
          name: name.isEmpty ? 'read_${i ~/ 4}' : name,
          type: detectType(seq),
          sequence: seq,
          qualityScores: quality.length == seq.length ? quality : null,
          source: source,
        ),
      );
    }
    return results;
  }

  /// Auto-detect format (FASTA vs FASTQ) and parse.
  static List<BioSequence> parseAuto(
    String content, {
    String source = 'upload',
  }) {
    final trimmed = content.trimLeft();
    if (trimmed.startsWith('@')) {
      final result = parseFastq(content, source: source);
      if (result.isNotEmpty) return result;
    }
    return parseFasta(content, source: source);
  }

  static String reverseComplement(String seq, {bool isRna = false}) {
    final map = isRna
        ? {'A': 'U', 'U': 'A', 'G': 'C', 'C': 'G', 'N': 'N'}
        : {'A': 'T', 'T': 'A', 'G': 'C', 'C': 'G', 'N': 'N'};
    return seq.split('').reversed.map((c) => map[c] ?? c).join();
  }

  static String complement(String seq, {bool isRna = false}) {
    final map = isRna
        ? {'A': 'U', 'U': 'A', 'G': 'C', 'C': 'G', 'N': 'N'}
        : {'A': 'T', 'T': 'A', 'G': 'C', 'C': 'G', 'N': 'N'};
    return seq.split('').map((c) => map[c] ?? c).join();
  }

  static double gcContent(String seq) {
    if (seq.isEmpty) return 0;
    final gc = seq.split('').where((c) => c == 'G' || c == 'C').length;
    return gc / seq.length * 100;
  }

  static double atContent(String seq) {
    if (seq.isEmpty) return 0;
    final at = seq
        .split('')
        .where((c) => c == 'A' || c == 'T' || c == 'U')
        .length;
    return at / seq.length * 100;
  }

  static Map<String, int> baseComposition(String seq) {
    final Map<String, int> comp = {};
    for (final c in seq.split('')) {
      comp[c] = (comp[c] ?? 0) + 1;
    }
    return comp;
  }

  static String translate(String dnaSeq) {
    final s = dnaSeq.toUpperCase().replaceAll('U', 'T');
    final buf = StringBuffer();
    for (int i = 0; i + 3 <= s.length; i += 3) {
      final codon = s.substring(i, i + 3);
      buf.write(_codonTable[codon] ?? 'X');
    }
    return buf.toString();
  }

  /// Generates k-mer set for similarity comparisons
  static Set<String> kmerSet(String seq, int k) {
    final Set<String> kmers = {};
    if (seq.length < k) return kmers;
    for (int i = 0; i <= seq.length - k; i++) {
      kmers.add(seq.substring(i, i + k));
    }
    return kmers;
  }

  static double kmerJaccardSimilarity(String a, String b, {int k = 6}) {
    final setA = kmerSet(a, k);
    final setB = kmerSet(b, k);
    if (setA.isEmpty || setB.isEmpty) return 0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 0 : intersection / union * 100;
  }
}
