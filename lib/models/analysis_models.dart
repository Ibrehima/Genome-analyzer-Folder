import 'package:uuid/uuid.dart';
import 'bio_sequence.dart';

/// ---------------- Primer Design ----------------
class PrimerCandidate {
  final String sequence;
  final int startPosition;
  final double gcContent;
  final double meltingTemp;
  final double hairpinRisk; // 0-1 (heuristic)
  final double selfDimerRisk; // 0-1 (heuristic)
  final double score; // overall quality 0-100

  PrimerCandidate({
    required this.sequence,
    required this.startPosition,
    required this.gcContent,
    required this.meltingTemp,
    required this.hairpinRisk,
    required this.selfDimerRisk,
    required this.score,
  });
}

class PrimerPairResult {
  final PrimerCandidate forward;
  final PrimerCandidate reverse;
  final int productSize;
  final double tmDifference;
  final double crossDimerRisk;
  final double pairScore;

  PrimerPairResult({
    required this.forward,
    required this.reverse,
    required this.productSize,
    required this.tmDifference,
    required this.crossDimerRisk,
    required this.pairScore,
  });
}

/// ---------------- Alignment ----------------
enum AlignmentMode { global, local }

class PairwiseAlignmentResult {
  final String alignedSeqA;
  final String alignedSeqB;
  final int score;
  final double identityPercent;
  final double similarityPercent;
  final int gaps;
  final AlignmentMode mode;

  PairwiseAlignmentResult({
    required this.alignedSeqA,
    required this.alignedSeqB,
    required this.score,
    required this.identityPercent,
    required this.similarityPercent,
    required this.gaps,
    required this.mode,
  });
}

class MultipleAlignmentResult {
  final List<String> names;
  final List<String> alignedSequences;
  final double averageIdentity;
  final int consensusLength;
  final String consensusSequence;

  MultipleAlignmentResult({
    required this.names,
    required this.alignedSequences,
    required this.averageIdentity,
    required this.consensusLength,
    required this.consensusSequence,
  });
}

/// ---------------- Phylogenetics ----------------
class PhyloNode {
  final String? label; // leaf name, null for internal
  final double branchLength;
  final List<PhyloNode> children;
  double x = 0;
  double y = 0;

  PhyloNode({this.label, this.branchLength = 0, List<PhyloNode>? children})
    : children = children ?? [];

  bool get isLeaf => children.isEmpty;

  /// Newick string representation
  String toNewick({bool root = true}) {
    if (isLeaf) {
      return '$label:${branchLength.toStringAsFixed(4)}';
    }
    final inner = children.map((c) => c.toNewick(root: false)).join(',');
    final body = '($inner)';
    return root ? '$body;' : '$body:${branchLength.toStringAsFixed(4)}';
  }
}

class PhyloTreeResult {
  final PhyloNode root;
  final String method; // UPGMA / Neighbor-Joining
  final List<String> leafNames;

  PhyloTreeResult({
    required this.root,
    required this.method,
    required this.leafNames,
  });
}

/// ---------------- Species / Lineage / Variant Identification ----------------
class ReferenceRecord {
  final String id;
  final String scientificName;
  final String commonName;
  final String
  lineage; // e.g. Domain;Kingdom;Phylum;Class;Order;Family;Genus;Species
  final String markerGene; // e.g. 16S rRNA, COI, ITS, rbcL
  final String sequence;

  ReferenceRecord({
    required this.id,
    required this.scientificName,
    required this.commonName,
    required this.lineage,
    required this.markerGene,
    required this.sequence,
  });
}

class SpeciesMatch {
  final ReferenceRecord reference;
  final double similarityPercent;
  final int sharedKmers;
  final int totalKmers;

  SpeciesMatch({
    required this.reference,
    required this.similarityPercent,
    required this.sharedKmers,
    required this.totalKmers,
  });
}

class VariantCall {
  final int position; // 0-based position relative to reference
  final String refBase;
  final String altBase;
  final String type; // SNP, Insertion, Deletion
  VariantCall({
    required this.position,
    required this.refBase,
    required this.altBase,
    required this.type,
  });
}

/// ---------------- Quality Control ----------------
class QualityReport {
  final String sequenceId;
  final String sequenceName;
  final int length;
  final double gcContent;
  final double atContent;
  final int nCount;
  final double nPercent;
  final double meanQuality; // -1 if unavailable
  final double minQuality;
  final double maxQuality;
  final Map<int, double> qualityPerPositionBin; // bin index -> mean quality
  final Map<String, int> baseComposition;
  final double q20Percent; // % bases with quality >= 20
  final double q30Percent; // % bases with quality >= 30
  final String overallGrade; // A, B, C, D

  QualityReport({
    required this.sequenceId,
    required this.sequenceName,
    required this.length,
    required this.gcContent,
    required this.atContent,
    required this.nCount,
    required this.nPercent,
    required this.meanQuality,
    required this.minQuality,
    required this.maxQuality,
    required this.qualityPerPositionBin,
    required this.baseComposition,
    required this.q20Percent,
    required this.q30Percent,
    required this.overallGrade,
  });
}

/// ---------------- Statistics ----------------
class DescriptiveStats {
  final double mean;
  final double median;
  final double stdDev;
  final double min;
  final double max;
  final int n;

  DescriptiveStats({
    required this.mean,
    required this.median,
    required this.stdDev,
    required this.min,
    required this.max,
    required this.n,
  });
}

class StatisticsReport {
  final DescriptiveStats lengthStats;
  final DescriptiveStats gcStats;
  final double shannonDiversityIndex;
  final double simpsonDiversityIndex;
  final Map<String, int> nucleotideFrequency;
  final int totalSequences;

  StatisticsReport({
    required this.lengthStats,
    required this.gcStats,
    required this.shannonDiversityIndex,
    required this.simpsonDiversityIndex,
    required this.nucleotideFrequency,
    required this.totalSequences,
  });
}

/// ---------------- Report / Export History ----------------
enum ExportFormat { pdf, docx, pptx, xlsx, txt }

class ReportHistoryItem {
  final String id;
  final String title;
  final String moduleType; // e.g. 'Primer Design', 'Alignment'
  final ExportFormat format;
  final DateTime createdAt;
  final String summary;

  ReportHistoryItem({
    String? id,
    required this.title,
    required this.moduleType,
    required this.format,
    DateTime? createdAt,
    this.summary = '',
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'moduleType': moduleType,
    'format': format.name,
    'createdAt': createdAt.toIso8601String(),
    'summary': summary,
  };

  factory ReportHistoryItem.fromJson(Map<String, dynamic> json) =>
      ReportHistoryItem(
        id: json['id'] as String?,
        title: json['title'] as String? ?? '',
        moduleType: json['moduleType'] as String? ?? '',
        format: ExportFormat.values.firstWhere(
          (e) => e.name == (json['format'] as String? ?? 'pdf'),
          orElse: () => ExportFormat.pdf,
        ),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        summary: json['summary'] as String? ?? '',
      );
}

/// ---------------- Raw Sequencing Data Processing ----------------
enum SequencingPlatform { illumina, nanopore, pacbio, sanger, unknown }

extension SequencingPlatformLabel on SequencingPlatform {
  String get label {
    switch (this) {
      case SequencingPlatform.illumina:
        return 'Illumina (short reads)';
      case SequencingPlatform.nanopore:
        return 'Oxford Nanopore (ONT)';
      case SequencingPlatform.pacbio:
        return 'PacBio (long reads)';
      case SequencingPlatform.sanger:
        return 'Sanger (capillary)';
      case SequencingPlatform.unknown:
        return 'Unknown / unrecognized';
    }
  }
}

/// A sample -> barcode mapping entry for Illumina-style demultiplexing.
class DemuxSample {
  final String name;
  final String barcode;
  DemuxSample({required this.name, required this.barcode});
}

/// Result of running a raw-read processing pipeline (detection,
/// demultiplexing, trimming, consensus) up to a clean FASTA/FASTQ output.
class SequencingPipelineResult {
  final SequencingPlatform platform;
  final List<String> stepsLog;
  final List<BioSequence> outputSequences;
  final List<String> warnings;
  final int inputReadCount;

  SequencingPipelineResult({
    required this.platform,
    required this.stepsLog,
    required this.outputSequences,
    this.warnings = const [],
    this.inputReadCount = 0,
  });
}

/// ---------------- RNA Analysis ----------------
enum RnaTypeGuess { mRNA, tRNA, rRNA, miRNA, lncRNA, siRNA, unknown }

extension RnaTypeGuessLabel on RnaTypeGuess {
  String get label {
    switch (this) {
      case RnaTypeGuess.mRNA:
        return 'Messenger RNA (mRNA)';
      case RnaTypeGuess.tRNA:
        return 'Transfer RNA (tRNA)';
      case RnaTypeGuess.rRNA:
        return 'Ribosomal RNA (rRNA)';
      case RnaTypeGuess.miRNA:
        return 'microRNA (miRNA)';
      case RnaTypeGuess.lncRNA:
        return 'Long non-coding RNA (lncRNA)';
      case RnaTypeGuess.siRNA:
        return 'Small interfering RNA (siRNA)';
      case RnaTypeGuess.unknown:
        return 'Undetermined RNA class';
    }
  }
}

class RnaClassificationResult {
  final RnaTypeGuess guess;
  final double confidence; // 0-100 heuristic confidence
  final List<String> reasons;
  final bool hasPolyATail;
  final int polyALength;
  final bool hasOrf;

  RnaClassificationResult({
    required this.guess,
    required this.confidence,
    required this.reasons,
    required this.hasPolyATail,
    required this.polyALength,
    required this.hasOrf,
  });
}

/// Simplified RNA secondary-structure prediction (Nussinov base-pair
/// maximization — NOT a full thermodynamic model like ViennaRNA/mfold).
class RnaFoldResult {
  final String sequence;
  final String dotBracket;
  final int pairCount;
  final double pseudoFreeEnergy; // heuristic proxy, kcal/mol-like units

  RnaFoldResult({
    required this.sequence,
    required this.dotBracket,
    required this.pairCount,
    required this.pseudoFreeEnergy,
  });
}

/// ---------------- Proteomics ----------------
class ProteinPropertiesResult {
  final String proteinSequence;
  final double molecularWeightDa;
  final double isoelectricPoint;
  final double gravyScore; // hydrophobicity, Kyte-Doolittle average
  final double aliphaticIndex;
  final double extinctionCoefficient280; // M^-1 cm^-1, reduced Cys assumed
  final Map<String, int> aminoAcidComposition;
  final Map<String, double> secondaryStructurePropensity; // helix/sheet/turn %
  final int numCysteines;
  final int numTryptophans;
  final int numTyrosines;

  ProteinPropertiesResult({
    required this.proteinSequence,
    required this.molecularWeightDa,
    required this.isoelectricPoint,
    required this.gravyScore,
    required this.aliphaticIndex,
    required this.extinctionCoefficient280,
    required this.aminoAcidComposition,
    required this.secondaryStructurePropensity,
    required this.numCysteines,
    required this.numTryptophans,
    required this.numTyrosines,
  });
}

/// ---------------- Annotation ----------------
class OrfResult {
  final int start; // 0-based, relative to the strand used
  final int end; // exclusive
  final int frame; // 1,2,3
  final bool forwardStrand;
  final int length;
  final String proteinPreview;

  OrfResult({
    required this.start,
    required this.end,
    required this.frame,
    required this.forwardStrand,
    required this.length,
    required this.proteinPreview,
  });
}

class SequenceAnnotation {
  final String id;
  final String sequenceId;
  final int start;
  final int end;
  final String label;
  final String featureType; // CDS, gene, ORF, motif, custom...
  final bool forwardStrand;
  final String note;
  final DateTime createdAt;

  SequenceAnnotation({
    String? id,
    required this.sequenceId,
    required this.start,
    required this.end,
    required this.label,
    required this.featureType,
    this.forwardStrand = true,
    this.note = '',
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'sequenceId': sequenceId,
    'start': start,
    'end': end,
    'label': label,
    'featureType': featureType,
    'forwardStrand': forwardStrand,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SequenceAnnotation.fromJson(Map<String, dynamic> json) =>
      SequenceAnnotation(
        id: json['id'] as String?,
        sequenceId: json['sequenceId'] as String? ?? '',
        start: json['start'] as int? ?? 0,
        end: json['end'] as int? ?? 0,
        label: json['label'] as String? ?? '',
        featureType: json['featureType'] as String? ?? 'custom',
        forwardStrand: json['forwardStrand'] as bool? ?? true,
        note: json['note'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// ---------------- 3D Structure & Stability ----------------
class Atom3D {
  final double x, y, z;
  final String label;
  final String kind; // backbone, basepair, helix, sheet, coil
  Atom3D({
    required this.x,
    required this.y,
    required this.z,
    required this.label,
    required this.kind,
  });
}

class Structure3DResult {
  final List<Atom3D> atoms;
  final List<List<int>> bonds; // index pairs into atoms
  final String modelKind; // 'dna_helix' or 'protein_backbone'

  Structure3DResult({
    required this.atoms,
    required this.bonds,
    required this.modelKind,
  });
}

class StabilityReport {
  final String sequenceName;
  final SequenceType type;
  final List<String> observations;
  final String overallAssessment;
  final double? estimatedTm; // for DNA/RNA
  final double? gravy; // for protein
  final double? aliphaticIndex; // for protein

  StabilityReport({
    required this.sequenceName,
    required this.type,
    required this.observations,
    required this.overallAssessment,
    this.estimatedTm,
    this.gravy,
    this.aliphaticIndex,
  });
}

/// ---------------- Therapeutic / Vaccine Target Analysis ----------------
class TransmembraneRegion {
  final int start;
  final int end;
  final double meanHydrophobicity;
  TransmembraneRegion({
    required this.start,
    required this.end,
    required this.meanHydrophobicity,
  });
}

class EpitopeCandidate {
  final int start;
  final int end;
  final String peptide;
  final double antigenicityScore; // heuristic 0-100
  final bool surfaceExposed;
  EpitopeCandidate({
    required this.start,
    required this.end,
    required this.peptide,
    required this.antigenicityScore,
    required this.surfaceExposed,
  });
}

class TargetAnalysisResult {
  final List<double> hydrophilicityProfile; // Parker scale, per-residue window
  final List<TransmembraneRegion> transmembraneRegions;
  final List<EpitopeCandidate> candidateEpitopes;
  final List<EpitopeCandidate> vaccineTargetCandidates;
  final String disclaimer;

  TargetAnalysisResult({
    required this.hydrophilicityProfile,
    required this.transmembraneRegions,
    required this.candidateEpitopes,
    required this.vaccineTargetCandidates,
    required this.disclaimer,
  });
}

/// ---------------- Domain-of-life classification ----------------
class DomainClassificationResult {
  final String
  domainLabel; // Human, Animal, Plant, Fungal, Bacterial, Viral, Archaeal, Protist, Unknown
  final double confidence; // 0-100
  final String basis; // explanation of how it was determined
  final ReferenceRecord? bestReference;

  DomainClassificationResult({
    required this.domainLabel,
    required this.confidence,
    required this.basis,
    this.bestReference,
  });
}

/// ---------------- Metabolomics ----------------
/// Curated local small-molecule reference record used for offline
/// metabolite lookup / mass-based triage (analogous in spirit to
/// [ReferenceRecord] for sequences). NOT a substitute for KEGG/HMDB/PubChem.
class MetaboliteRecord {
  final String id;
  final String name;
  final String formula; // e.g. 'C6H12O6'
  final String metaboliteClass; // Carbohydrate, Amino acid, Lipid, ...
  final String pathway; // e.g. 'Glycolysis', 'TCA cycle'
  final String description;

  MetaboliteRecord({
    required this.id,
    required this.name,
    required this.formula,
    required this.metaboliteClass,
    required this.pathway,
    required this.description,
  });
}

/// Result of computing molecular weight / elemental composition from a
/// chemical formula string (average + monoisotopic mass).
class FormulaMassResult {
  final String formula;
  final Map<String, int> elementCounts;
  final double averageMassDa;
  final double monoisotopicMassDa;

  FormulaMassResult({
    required this.formula,
    required this.elementCounts,
    required this.averageMassDa,
    required this.monoisotopicMassDa,
  });
}

/// A candidate metabolite match from mass-based (MS-style) identification.
class MassSearchMatch {
  final MetaboliteRecord metabolite;
  final double theoreticalMass;
  final double deltaPpm;
  final String adduct;

  MassSearchMatch({
    required this.metabolite,
    required this.theoreticalMass,
    required this.deltaPpm,
    required this.adduct,
  });
}
