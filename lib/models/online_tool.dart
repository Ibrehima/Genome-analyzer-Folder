/// Represents an external, publicly available bioinformatics tool/database
/// that the app links out to. The app cannot embed third-party OAuth logins,
/// but it can deep-link into these sites so the user can sign in to their
/// own personal account directly on the provider's website, or jump
/// straight to a pre-filled search/query page instead of their generic
/// landing page.
class OnlineTool {
  final String name;
  final String description;
  final String url;
  final String category;
  final bool supportsAccount;

  /// Direct sign-in / account page on the provider's site (used by the
  /// "Se connecter" button in the Online Tools Hub). Falls back to [url]
  /// when null.
  final String? loginUrl;

  /// A URL template containing the token `{query}` which, once the user's
  /// search text is URL-encoded and substituted in, opens the provider's
  /// site with the query already applied (e.g. a pre-filled species search
  /// or BLAST query) instead of just the generic landing page. Null when
  /// the tool has no simple query-string deep-link.
  final String? queryUrlTemplate;

  /// A short hint shown next to the query field (e.g. "Gene symbol",
  /// "Scientific name", "Sequence (FASTA)")
  final String? queryHint;

  const OnlineTool({
    required this.name,
    required this.description,
    required this.url,
    required this.category,
    this.supportsAccount = false,
    this.loginUrl,
    this.queryUrlTemplate,
    this.queryHint,
  });

  bool get supportsDirectQuery => queryUrlTemplate != null;

  String buildQueryUrl(String query) {
    final encoded = Uri.encodeComponent(query.trim());
    return (queryUrlTemplate ?? url).replaceAll('{query}', encoded);
  }
}

class OnlineToolsCatalog {
  static const List<OnlineTool> tools = [
    OnlineTool(
      name: 'NCBI BLAST',
      description: 'Sequence similarity search against GenBank & RefSeq databases.',
      url: 'https://blast.ncbi.nlm.nih.gov/Blast.cgi',
      category: 'Alignment & Search',
      supportsAccount: true,
      loginUrl: 'https://www.ncbi.nlm.nih.gov/account/signin/',
      queryUrlTemplate:
          'https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastSearch&PROGRAM=blastn&QUERY={query}',
      queryHint: 'Sequence (FASTA or raw)',
    ),
    OnlineTool(
      name: 'NCBI GenBank / Nucleotide',
      description: 'Download reference sequences and genome records.',
      url: 'https://www.ncbi.nlm.nih.gov/nuccore',
      category: 'Sequence Repository',
      supportsAccount: true,
      loginUrl: 'https://www.ncbi.nlm.nih.gov/account/signin/',
      queryUrlTemplate: 'https://www.ncbi.nlm.nih.gov/nuccore/?term={query}',
      queryHint: 'Accession, gene or organism',
    ),
    OnlineTool(
      name: 'NCBI Entrez / PubMed',
      description: 'Literature search linked to sequence records.',
      url: 'https://pubmed.ncbi.nlm.nih.gov/',
      category: 'Literature',
      queryUrlTemplate: 'https://pubmed.ncbi.nlm.nih.gov/?term={query}',
      queryHint: 'Keywords / authors / gene',
    ),
    OnlineTool(
      name: 'EBI Job Dispatcher (Clustal Omega / MUSCLE)',
      description: 'Run production-grade multiple sequence alignments online.',
      url: 'https://www.ebi.ac.uk/jdispatcher/msa',
      category: 'Alignment & Search',
      queryUrlTemplate: 'https://www.ebi.ac.uk/jdispatcher/msa/clustalo',
      queryHint: 'Opens the submission form (paste sequences there)',
    ),
    OnlineTool(
      name: 'EBI EMBL-EBI Search',
      description: 'Search across EMBL, UniProt, Ensembl and more.',
      url: 'https://www.ebi.ac.uk/ebisearch/',
      category: 'Sequence Repository',
      queryUrlTemplate: 'https://www.ebi.ac.uk/ebisearch/search.ebi?query={query}',
      queryHint: 'Gene, protein or keyword',
    ),
    OnlineTool(
      name: 'UniProt',
      description: 'Protein sequence & functional annotation database.',
      url: 'https://www.uniprot.org/',
      category: 'Sequence Repository',
      supportsAccount: true,
      loginUrl: 'https://www.uniprot.org/',
      queryUrlTemplate: 'https://www.uniprot.org/uniprotkb?query={query}',
      queryHint: 'Protein name, gene or accession',
    ),
    OnlineTool(
      name: 'Ensembl Genome Browser',
      description: 'Genome annotation, variants & comparative genomics.',
      url: 'https://www.ensembl.org/',
      category: 'Genome Browser',
      queryUrlTemplate:
          'https://www.ensembl.org/Multi/Search/Results?q={query};site=ensembl',
      queryHint: 'Gene symbol or species',
    ),
    OnlineTool(
      name: 'Primer3Plus',
      description: 'Reference online primer design tool (cross-check results).',
      url: 'https://www.primer3plus.com/',
      category: 'Primer Design',
    ),
    OnlineTool(
      name: 'iTOL (Interactive Tree of Life)',
      description: 'Upload a Newick tree for advanced phylogenetic visualization.',
      url: 'https://itol.embl.de/',
      category: 'Phylogenetics',
      supportsAccount: true,
      loginUrl: 'https://itol.embl.de/login.cgi',
    ),
    OnlineTool(
      name: 'MEGA Software',
      description: 'Desktop tool for advanced molecular evolutionary genetics analysis.',
      url: 'https://www.megasoftware.net/',
      category: 'Phylogenetics',
    ),
    OnlineTool(
      name: 'BOLD Systems',
      description: 'Barcode of Life Data System for species identification via DNA barcodes.',
      url: 'https://boldsystems.org/',
      category: 'Species ID',
      supportsAccount: true,
      loginUrl: 'https://boldsystems.org/',
      queryUrlTemplate: 'https://boldsystems.org/data/portal/?q={query}',
      queryHint: 'Species or barcode ID',
    ),
    OnlineTool(
      name: 'GBIF',
      description: 'Global Biodiversity Information Facility — species occurrence & taxonomy.',
      url: 'https://www.gbif.org/',
      category: 'Species ID',
      supportsAccount: true,
      loginUrl: 'https://www.gbif.org/user/profile',
      queryUrlTemplate: 'https://www.gbif.org/species/search?q={query}',
      queryHint: 'Scientific name',
    ),
    OnlineTool(
      name: 'GISAID',
      description: 'Viral genome sequence sharing (e.g. influenza, SARS-CoV-2 variants).',
      url: 'https://gisaid.org/',
      category: 'Variants',
      supportsAccount: true,
      loginUrl: 'https://platform.gisaid.org/epi3/frontend',
    ),
    OnlineTool(
      name: 'Ensembl VEP (Variant Effect Predictor)',
      description: 'Annotate and predict the effect of genomic variants.',
      url: 'https://www.ensembl.org/Tools/VEP',
      category: 'Variants',
    ),
    OnlineTool(
      name: 'FastQC (Babraham)',
      description: 'Reference tool for high-throughput sequence quality control.',
      url: 'https://www.bioinformatics.babraham.ac.uk/projects/fastqc/',
      category: 'Quality Control',
    ),
    OnlineTool(
      name: 'Galaxy Project',
      description: 'Web-based platform for accessible, reproducible bioinformatics workflows.',
      url: 'https://usegalaxy.org/',
      category: 'Workflow Platform',
      supportsAccount: true,
      loginUrl: 'https://usegalaxy.org/login/start',
    ),
  ];

  static List<String> get categories => tools.map((t) => t.category).toSet().toList()..sort();
}
