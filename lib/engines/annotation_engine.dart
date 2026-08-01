import '../models/analysis_models.dart';
import 'sequence_engine.dart';

/// ORF discovery (6-frame scan) and GFF3 export for manual/automatic
/// sequence feature annotations.
class AnnotationEngine {
  static const Set<String> _stopCodons = {'TAA', 'TAG', 'TGA'};

  /// Scans all 3 forward + 3 reverse-complement reading frames for
  /// ATG...stop open reading frames of at least [minLengthNt] nucleotides.
  static List<OrfResult> findOrfs(String rawSeq, {int minLengthNt = 100}) {
    final results = <OrfResult>[];
    final fwd = rawSeq.toUpperCase().replaceAll('U', 'T');
    final rev = SequenceEngine.reverseComplement(fwd);
    final strands = [
      {'seq': fwd, 'forward': true},
      {'seq': rev, 'forward': false},
    ];

    for (final strand in strands) {
      final seq = strand['seq'] as String;
      final forward = strand['forward'] as bool;
      for (int frame = 0; frame < 3; frame++) {
        int i = frame;
        while (i + 3 <= seq.length) {
          final codon = seq.substring(i, i + 3);
          if (codon == 'ATG') {
            int j = i;
            bool foundStop = false;
            while (j + 3 <= seq.length) {
              final c = seq.substring(j, j + 3);
              if (_stopCodons.contains(c)) {
                foundStop = true;
                break;
              }
              j += 3;
            }
            if (foundStop) {
              final orfLen = j + 3 - i;
              if (orfLen >= minLengthNt) {
                final protein = SequenceEngine.translate(
                  seq.substring(i, j + 3),
                );
                final preview = protein.length > 60
                    ? '${protein.substring(0, 60)}...'
                    : protein;
                results.add(
                  OrfResult(
                    start: i,
                    end: j + 3,
                    frame: frame + 1,
                    forwardStrand: forward,
                    length: orfLen,
                    proteinPreview: preview,
                  ),
                );
              }
              i = j + 3;
            } else {
              i += 3;
            }
          } else {
            i += 3;
          }
        }
      }
    }
    results.sort((a, b) => b.length.compareTo(a.length));
    return results.take(200).toList();
  }

  /// Serializes a list of annotations for one sequence into GFF3 text.
  static String toGff3(String seqId, List<SequenceAnnotation> annotations) {
    final buf = StringBuffer();
    buf.writeln('##gff-version 3');
    buf.writeln('##sequence-region $seqId');
    for (final a in annotations) {
      final strand = a.forwardStrand ? '+' : '-';
      final attrParts = <String>[
        'ID=${a.id}',
        'Name=${Uri.encodeComponent(a.label)}',
      ];
      if (a.note.isNotEmpty) {
        attrParts.add('Note=${Uri.encodeComponent(a.note)}');
      }
      buf.writeln(
        [
          seqId,
          'GenomeAnalyzer',
          a.featureType,
          '${a.start + 1}',
          '${a.end}',
          '.',
          strand,
          '.',
          attrParts.join(';'),
        ].join('\t'),
      );
    }
    return buf.toString();
  }
}
