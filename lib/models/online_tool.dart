/// Represents an external, publicly available bioinformatics tool/database
/// that the app links out to. The app cannot embed third-party OAuth logins,
/// but it can deep-link into these sites so the user can sign in to their
/// own personal account directly on the provider's website.
class OnlineTool {
  final String name;
  final String description;
  final String url;
  final String category;
  final bool supportsAccount;

  const OnlineTool({
    required this.name,
    required this.description,
    required this.url,
    required this.category,
    this.supportsAccount = false,
  });
}

class OnlineToolsCatalog {
  static const List<OnlineTool> tools = [
    OnlineTool(
      name: 'NCBI BLAST',
      description:
          'Sequence similarity search against GenBank & RefSeq databases.',
      url: 'https://blast.ncbi.nlm.nih.gov/Blast.cgi',
      category: 'Alignment & Search',
      supportsAccount: true,
    ),
    OnlineTool(
      name: 'NCBI GenBank / Nucleotide',
      description: 'Download reference sequences and genome records.',
      url: 'https://www.ncbi.nlm.nih.gov/nuccore',
      category: 'Sequence Repository',
      supportsAccount: true,
    ),
    OnlineTool(
      name: 'NCBI Entrez / PubMed',
      description: 'Literature search linked to sequence records.',
      url: 'https://pubmed.ncbi.nlm.nih.gov/',
      category: 'Literature',
    ),
    OnlineTool(
      name: 'EBI Job Dispatcher (Clustal Omega / MUSCLE)',
      description: 'Run production-grade multiple sequence alignments online.',
      url: 'https://www.ebi.ac.uk/jdispatcher/msa',
      category: 'Alignment & Search',
    ),
    OnlineTool(
      name: 'EBI EMBL-EBI Search',
      description: 'Search across EMBL, UniProt, Ensembl and more.',
      url: 'https://www.ebi.ac.uk/ebisearch/',
      category: 'Sequence Repository',
    ),
    OnlineTool(
      name: 'UniProt',
      description: 'Protein sequence & functional annotation database.',
      url: 'https://www.uniprot.org/',
      category: 'Sequence Repository',
      supportsAccount: true,
    ),
    OnlineTool(
      name: 'Ensembl Genome Browser',
      description: 'Genome annotation, variants & comparative genomics.',
      url: 'https://www.ensembl.org/',
      category: 'Genome Browser',
    ),
    OnlineTool(
      name: 'Primer3Plus',
      description: 'Reference online primer design tool (cross-check results).',
      url: 'https://www.primer3plus.com/',
      category: 'Primer Design',
    ),
    OnlineTool(
      name: 'iTOL (Interactive Tree of Life)',
      description:
          'Upload a Newick tree for advanced phylogenetic visualization.',
      url: 'https://itol.embl.de/',
      category: 'Phylogenetics',
      supportsAccount: true,
    ),
    OnlineTool(
      name: 'MEGA Software',
      description:
          'Desktop tool for advanced molecular evolutionary genetics analysis.',
      url: 'https://www.megasoftware.net/',
      category: 'Phylogenetics',
    ),
    OnlineTool(
      name: 'BOLD Systems',
      description:
          'Barcode of Life Data System for species identification via DNA barcodes.',
      url: 'https://www.boldsystems.org/',
      category: 'Species ID',
      supportsAccount: true,
    ),
    OnlineTool(
      name: 'GBIF',
      description:
          'Global Biodiversity Information Facility — species occurrence & taxonomy.',
      url: 'https://www.gbif.org/',
      category: 'Species ID',
      supportsAccount: true,
    ),
    OnlineTool(
      name: 'GISAID',
      description:
          'Viral genome sequence sharing (e.g. influenza, SARS-CoV-2 variants).',
      url: 'https://gisaid.org/',
      category: 'Variants',
      supportsAccount: true,
    ),
    OnlineTool(
      name: 'Ensembl VEP (Variant Effect Predictor)',
      description: 'Annotate and predict the effect of genomic variants.',
      url: 'https://www.ensembl.org/Tools/VEP',
      category: 'Variants',
    ),
    OnlineTool(
      name: 'FastQC (Babraham)',
      description:
          'Reference tool for high-throughput sequence quality control.',
      url: 'https://www.bioinformatics.babraham.ac.uk/projects/fastqc/',
      category: 'Quality Control',
    ),
    OnlineTool(
      name: 'Galaxy Project',
      description:
          'Web-based platform for accessible, reproducible bioinformatics workflows.',
      url: 'https://usegalaxy.org/',
      category: 'Workflow Platform',
      supportsAccount: true,
    ),
  ];

  static List<String> get categories =>
      tools.map((t) => t.category).toSet().toList()..sort();
}
