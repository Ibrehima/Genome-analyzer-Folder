import '../models/analysis_models.dart';

/// Curated local reference sequence database used for offline species,
/// lineage and variant identification via k-mer similarity matching.
/// NOTE: Sequences are representative/illustrative marker-gene fragments
/// for demonstration purposes (not verbatim GenBank entries). When online,
/// the app can query live NCBI/BOLD/GBIF databases for authoritative results.
class ReferenceDatabase {
  static final List<ReferenceRecord> records = [
    ReferenceRecord(
      id: 'REF001',
      scientificName: 'Escherichia coli',
      commonName: 'E. coli',
      lineage:
          'Bacteria;Proteobacteria;Gammaproteobacteria;Enterobacterales;Enterobacteriaceae;Escherichia;Escherichia coli',
      markerGene: '16S rRNA',
      sequence:
          'TATATAAGTACGTGCAATCCAACCTTCAGGAAAGGATAAGAGGATCTAATTGGAGGTCAAAAAGAATAAGATTAACATTCTTTCATTAACGCGATGCAAGTTGTAAAGATTCCTTGAGCAAGCCTCAGGATCCAATGGATTTCAGTAATAAAAGCCCTAGTAAGGATTTGTTTCGTTCCGGCCGATTATTTCGATTATAT',
    ),
    ReferenceRecord(
      id: 'REF002',
      scientificName: 'Staphylococcus aureus',
      commonName: 'Staph aureus',
      lineage:
          'Bacteria;Firmicutes;Bacilli;Bacillales;Staphylococcaceae;Staphylococcus;Staphylococcus aureus',
      markerGene: '16S rRNA',
      sequence:
          'AATCAGCTCATGTTAGCCCTAATTCGCTCATTACGTCGAAGTTTGCAGGAAGGCGATATACTTTTCATGCAGGGAAGTCTATGTTTTTCATATACTTCAATTAACTATCGAAGTATACATTTCCTTGAATCATTAGTTTGTTCGTGAATGTAACATGTGCATAAATGCAGCATAATATAAAACAAACACAAAACCTCTCTGGACCTTATACTAATCCGTT',
    ),
    ReferenceRecord(
      id: 'REF003',
      scientificName: 'Bacillus subtilis',
      commonName: 'Hay bacillus',
      lineage:
          'Bacteria;Firmicutes;Bacilli;Bacillales;Bacillaceae;Bacillus;Bacillus subtilis',
      markerGene: '16S rRNA',
      sequence:
          'CTCGACAGCTACGCTAGCTGCACGAGAGGTACCCTAGCAAGGTCGAGCAGTTGTCTTTCAATGGACACGCCATGGTTTTTGGCGATGCAAGGCTGAACACTGATGATGAGTCTCGCTAGTTGCGGGATTGGCAAAGTATTCTTTTACTGGATAAGCCCAAATCCACTGCTATTCACTTTCACTGCCGTTAGTAGTCGGAGTTAGGTCGTGTGGGTAACTCCCATCAGACGAGGTGCCTGA',
    ),
    ReferenceRecord(
      id: 'REF004',
      scientificName: 'Salmonella enterica',
      commonName: 'Salmonella',
      lineage:
          'Bacteria;Proteobacteria;Gammaproteobacteria;Enterobacterales;Enterobacteriaceae;Salmonella;Salmonella enterica',
      markerGene: '16S rRNA',
      sequence:
          'TTTTCGTATAGGTCCCTAACCTAACACATGAAATTAACTAGCAGAAGCGTGTTGCCCCTTCGAGCAACCAAGCAGAGCCGTTATAACCACCTATTGAAAGCACAGAAGAATGAGAGCTATATGGGACCAAACATTATACTATGTAACGCCTTGTGGAGGTATCTCTCGCGACTCTAAAAAGTGTACTGTTATCTGCATATACTGTCATCCCGGACCTTTGGTATCTCGCCATACTAGGTAAGTCGGTGTGATTCCGAGGG',
    ),
    ReferenceRecord(
      id: 'REF005',
      scientificName: 'Mycobacterium tuberculosis',
      commonName: 'TB bacterium',
      lineage:
          'Bacteria;Actinobacteria;Actinomycetia;Corynebacteriales;Mycobacteriaceae;Mycobacterium;Mycobacterium tuberculosis',
      markerGene: '16S rRNA',
      sequence:
          'GCCTATGGCCGTGTCCGTGATATACTGGCCTACTTATGCGATTAGAAACGACCGTACTAACGCTTTTTCAGGGCTTGGAGCGAGCTGGTGTCGATCTCGGAAGTGTGCATGCTATAAAGACAGGATGTTGTATGCTGAATGGCCTCCGCTCCGGCTGGTCTTAAACAATCGCGCGAGCTT',
    ),
    ReferenceRecord(
      id: 'REF006',
      scientificName: 'Vibrio cholerae',
      commonName: 'Cholera bacterium',
      lineage:
          'Bacteria;Proteobacteria;Gammaproteobacteria;Vibrionales;Vibrionaceae;Vibrio;Vibrio cholerae',
      markerGene: '16S rRNA',
      sequence:
          'TCGCCTGCGAGAATCCGCCTCGTGAAGTATATTCCGATCCGGCCCTCTAGGAGGCCGCTTGAATTGTATAGAGGGCGTTCCGTATCGTAGCAATATTCGCGGACGTAAGGCTTATCGCGACCCTCGCTTTTCCACCCACCCGACAAATATTTACGGTGCCCTTCGGCAAATAATATCGTAGCCGTAAACAACCAAGATGC',
    ),
    ReferenceRecord(
      id: 'REF007',
      scientificName: 'Pseudomonas aeruginosa',
      commonName: 'P. aeruginosa',
      lineage:
          'Bacteria;Proteobacteria;Gammaproteobacteria;Pseudomonadales;Pseudomonadaceae;Pseudomonas;Pseudomonas aeruginosa',
      markerGene: '16S rRNA',
      sequence:
          'AAAGATTACTTCAATTCTTTTTAACTCACTTAAAAACCGTCCGAGTTTGATTGATGGATACCCTATGATTAATGATAGTATCGTCCATCTTTAATTTACCTCACTTTCTTCTTTATCTGCTTTCAACACTAGTAATATCTCCCTTTTCACTTTCTTATAGATTAGATTATAGTTAAATAGGGGTTATTAGTTAGTTAACAACAGAATTATGTATAATTAG',
    ),
    ReferenceRecord(
      id: 'REF008',
      scientificName: 'Homo sapiens',
      commonName: 'Human',
      lineage:
          'Eukaryota;Animalia;Chordata;Mammalia;Primates;Hominidae;Homo;Homo sapiens',
      markerGene: 'COI (mtDNA)',
      sequence:
          'ATTATCAGGGTCCACAATGCCAATAAAAATATTACTAGGTAGGTCCCTTCCCAACCGGAGCCCGCTAATTTATTCACTATGTGAAAATGAGTTTATTTGCTTCAATTACCCAGTCCGACAAAATTCTGTGGTTCGGTTATAATTCAATCTCGTTAACTTAATTTGACGACTATATATAACTAGATTTGGTCTTCCTTCGTCAGTATGTACTCTACAATTACATTTTTAACCAGTTTGCTC',
    ),
    ReferenceRecord(
      id: 'REF009',
      scientificName: 'Mus musculus',
      commonName: 'House mouse',
      lineage:
          'Eukaryota;Animalia;Chordata;Mammalia;Rodentia;Muridae;Mus;Mus musculus',
      markerGene: 'COI (mtDNA)',
      sequence:
          'CCAAGCTGGATATTAATTCCGAACCGTGTCACAAAAGCGTAGCTAAGGATCTCACAATCCAAGATACCGTTCCTTAGAAGGTGTAGATATACCGGGATAAGCTCGCGAAGGGATGCATGTTTACACAGACCCTTGGACAACTAAACAAACAATGTACAGCCGCGACAGCTGTCGCGGATAAGTTTTTGGCTATTAGGCACCGATCTAAGAATAGCCGTTAGGTATACCCACACCGCAGCATGACTAATGCTAATCATCAA',
    ),
    ReferenceRecord(
      id: 'REF010',
      scientificName: 'Canis lupus familiaris',
      commonName: 'Dog',
      lineage:
          'Eukaryota;Animalia;Chordata;Mammalia;Carnivora;Canidae;Canis;Canis lupus familiaris',
      markerGene: 'COI (mtDNA)',
      sequence:
          'TTGGCGGGGTTAGGATCCATATGAGCGCAAAAGTGTTAGGGGCGGATCTTGACTAGGTATTGTCGTATTTAACGGTCTCAGATGCAGCGTTGGTCACTCTGGAACACCTGAGGTCCTAATTGAATGAGATTGAGTTCCTAACTTTAAATAGAATTGATCATGTTATTAAGGGGGAAATGA',
    ),
    ReferenceRecord(
      id: 'REF011',
      scientificName: 'Felis catus',
      commonName: 'Cat',
      lineage:
          'Eukaryota;Animalia;Chordata;Mammalia;Carnivora;Felidae;Felis;Felis catus',
      markerGene: 'COI (mtDNA)',
      sequence:
          'TCCTGCCAGAGTCTCCATTCATATTTTATCATAGGGTAGACTTTACTGTCAGTTTTTTTAGAATGCGGAGACTAGCTATACACCAGGCGTACTTTTGATCCAAATAGCACTCCTCTGTAGTCAGTTCTTTCTAACGGTTTCGTAGCCTTGTGACCCCTAGGCATAAGGCAGATAGTTAAGTACTTAACGGTACATGGAGC',
    ),
    ReferenceRecord(
      id: 'REF012',
      scientificName: 'Gallus gallus',
      commonName: 'Chicken',
      lineage:
          'Eukaryota;Animalia;Chordata;Aves;Galliformes;Phasianidae;Gallus;Gallus gallus',
      markerGene: 'COI (mtDNA)',
      sequence:
          'CGTGCACCTCTGCCCCAGGGGCAGTCCGACGACACGCTCCCGCACATTTGTATACGCGACTGAGGTACCTGTTTCTAATATTGCCCGCCATCCTGGGGCAAAGTTGTGCATCGGACTGTCGCGGCGTGACGTGGCTTGCAGATGGACGATAAGCCGGGGAACCTTAACAGCACGGAACGTTACCTTACCTCCAAATTACTTGTACGTCGATGCCCTCGTT',
    ),
    ReferenceRecord(
      id: 'REF013',
      scientificName: 'Danio rerio',
      commonName: 'Zebrafish',
      lineage:
          'Eukaryota;Animalia;Chordata;Actinopterygii;Cypriniformes;Danionidae;Danio;Danio rerio',
      markerGene: 'COI (mtDNA)',
      sequence:
          'CGATGTTTTATTTTATTCCCCGCCCTGCCCTGGCCACACTGGTGCGATGAATCCGCCTTTGTTTAACCCCACTTCAACAACTGCAGTTTCCGTAGGATACTCGTGAAACTACGTTCTACGATTTGTGTTAGCGAGTGTACACGGCTGAGGAGGTACACAACTCCTGATCACCGGAGGTAGGGTTAACTATCCCTGCGCCGTAGAACGGGGTGACAGGCCGCTTGAATTCACTGATGGTTC',
    ),
    ReferenceRecord(
      id: 'REF014',
      scientificName: 'Drosophila melanogaster',
      commonName: 'Fruit fly',
      lineage:
          'Eukaryota;Animalia;Arthropoda;Insecta;Diptera;Drosophilidae;Drosophila;Drosophila melanogaster',
      markerGene: 'COI (mtDNA)',
      sequence:
          'TAATGGCAAATTAGTACGTAGCCCTCAACATAATAATTATTGTTTTCAAACATAGAATCTCGTGGTAGGCGGATCTTAACAAATTAAATTTAAGTTATGAATGCATAAGCTTACAATACTATAGCGAGTTCGACCGTCCCTGCCATAACAATCTTTGGATTTTCTAGCCTCGAAAACAGTGCCATTACATAAATAGTTTATACTACACGCGGAATTGCCATTCATACAGATCAGGCTACAGTTATAGGTGTAATTCAGGG',
    ),
    ReferenceRecord(
      id: 'REF015',
      scientificName: 'Apis mellifera',
      commonName: 'Honey bee',
      lineage:
          'Eukaryota;Animalia;Arthropoda;Insecta;Hymenoptera;Apidae;Apis;Apis mellifera',
      markerGene: 'COI (mtDNA)',
      sequence:
          'AGTACTTAAGCATAAGTCGCTCATCAGTAATCATCGACAGGGTTTAGTCCGGTGTGCCAAGTTATGCCTAGGCATTTCGGATCTTGAATGACAGGGTTTATGAGGGTGCTAAAACGACTTTTTCTGGCTCCAGAGAAGCCATATATTCGCTGCCGTTTCCTCAAGATATTCGGACGTGTG',
    ),
    ReferenceRecord(
      id: 'REF016',
      scientificName: 'Bos taurus',
      commonName: 'Cattle',
      lineage:
          'Eukaryota;Animalia;Chordata;Mammalia;Artiodactyla;Bovidae;Bos;Bos taurus',
      markerGene: 'COI (mtDNA)',
      sequence:
          'TTCGTAGAACAATTCTGCTCATAATGACCCCTTAATGTACTAGAATATTCGCGGAATGCGGAAATTCTCACCCTTAATATAATATCTATCAAATGAAATATTCAACGTGATGCCTCGTGTCGCTAGATTTACCATAATCTTTTATTCCATAACATCAAAAAAGAATCAAAGTACGTACCCACAGCACGCTGGTATTCCTA',
    ),
    ReferenceRecord(
      id: 'REF017',
      scientificName: 'Oryctolagus cuniculus',
      commonName: 'Rabbit',
      lineage:
          'Eukaryota;Animalia;Chordata;Mammalia;Lagomorpha;Leporidae;Oryctolagus;Oryctolagus cuniculus',
      markerGene: 'COI (mtDNA)',
      sequence:
          'TTCGACTTAGTGGCGGCGAAGCCTTAAGTACACCTTAATCAAGTGCATCCATAAGCACTAGGTCGTAATAGCATTTCAAACTGTACGCTTCCATTCGATTTTAGTTGTACAATGGCAAAGGCGAAGCTATCTTACTAGATAGTTAGACCAAATAGCTCCCGACTCACCACTTTGTATGTGCAGTAGTTAATTACACAAACCCAGATAGTATCGTTGATTA',
    ),
    ReferenceRecord(
      id: 'REF018',
      scientificName: 'Arabidopsis thaliana',
      commonName: 'Thale cress',
      lineage:
          'Eukaryota;Plantae;Streptophyta;Magnoliopsida;Brassicales;Brassicaceae;Arabidopsis;Arabidopsis thaliana',
      markerGene: 'rbcL',
      sequence:
          'ATATCGCCATGCAATTCTGGGTAGATAAAGTCTGCGTGGTTTACGACTGTTACTTACTGTCTTAAGTGCAGAGGCGCATCGCTGACTCTAACGACATAGGCACACATGGTACTTGACGCAAGAGTGAAATAGGCGACCCAAAATTTTCTTCAGACGAGATTTTGTACATTGCTAGAACCAATCCTCTGACGAAGAGACGATCTTATGTGGAAAGTAATAACCCTGGTACCACCTTCCGCC',
    ),
    ReferenceRecord(
      id: 'REF019',
      scientificName: 'Oryza sativa',
      commonName: 'Rice',
      lineage:
          'Eukaryota;Plantae;Streptophyta;Liliopsida;Poales;Poaceae;Oryza;Oryza sativa',
      markerGene: 'rbcL',
      sequence:
          'TGACCCCTAATAGATCAAACAGGTTACGCAAATCAATTAAGTGCAATGGCAGTAGCAGGGCGTCTTGGATAGACCCTCTGTTTGAGAGAGGGGAAAGCCGACCAAATGCCTCCAATAATCCCGAGTCGCCGTACGTTAACAGTAGTATGACAGGCGGCGCTAAATGAACTATTGGATTCGGGGATATAAAAACGCCTAAACGCAGCTACGCAGTCAGGGTCGATCGCTACTCTTATTATCTCCAGTAATCATATGGTTAA',
    ),
    ReferenceRecord(
      id: 'REF020',
      scientificName: 'Zea mays',
      commonName: 'Maize',
      lineage:
          'Eukaryota;Plantae;Streptophyta;Liliopsida;Poales;Poaceae;Zea;Zea mays',
      markerGene: 'rbcL',
      sequence:
          'TGCTCGAATTACAACTAGCTAACTTTTCGTCTCTGTCGAACGCTGCCAATGGTCCCACATTCAGATTGCTCTACTTCCGCTATGAGCGCAGCGTGCACACATCAGACGCATCCCGACCCAAAGGTCCACAGGGAGTAATAACAGAAAACCACGACTGCTGGCCACACCCGCAAGTCCGAC',
    ),
    ReferenceRecord(
      id: 'REF021',
      scientificName: 'Solanum lycopersicum',
      commonName: 'Tomato',
      lineage:
          'Eukaryota;Plantae;Streptophyta;Magnoliopsida;Solanales;Solanaceae;Solanum;Solanum lycopersicum',
      markerGene: 'rbcL',
      sequence:
          'ATTTTAAGTTCCTCTATTTTACTGGATAGACTGCAAGCTTTTTATTAACATTGATTAGAATATCACATATCAACGACAGAAATGGTACAGGGAGTAGACCAACTTTGTCCCGAAAAAATAATTTTTTCTTAAGTTTTAAGAAGTTCATAGATTTTAAAGACTTGATACTACATCCCTTATCAAGTGTACCGGAATATATG',
    ),
    ReferenceRecord(
      id: 'REF022',
      scientificName: 'Triticum aestivum',
      commonName: 'Wheat',
      lineage:
          'Eukaryota;Plantae;Streptophyta;Liliopsida;Poales;Poaceae;Triticum;Triticum aestivum',
      markerGene: 'rbcL',
      sequence:
          'CGTGAGCAAGGTAGTCGTCGCAGTACACTCACACATTGTCATGGTAAAAGGAGTTTGAGTTTGCTTCTTATTAAGAAAAGATTCAACTGGTATATGAGATAGCTTTGTTATTAGCTTGAAAATACTATGCTTTAAACGGGGTACCCATCGCTAATCATTTCATAGTTTACCTAATATATTCAAGGAATTCATAATAGTATCACGTATTTGCTTTCAGCGG',
    ),
    ReferenceRecord(
      id: 'REF023',
      scientificName: 'Saccharomyces cerevisiae',
      commonName: "Baker's yeast",
      lineage:
          'Eukaryota;Fungi;Ascomycota;Saccharomycetes;Saccharomycetales;Saccharomycetaceae;Saccharomyces;Saccharomyces cerevisiae',
      markerGene: 'ITS',
      sequence:
          'AGTTATAACCATCGTACAGGTACTAGATACGAGATCCGTCTTGGTCCCGGCCACTGTTTGGAAAACAAACATAGTTTCCGACTAAGAATCGACAGTGTGAGACGAATAACATATCTATTTGTTAAAAATTCTGTCCTAGAAGAAATTACTCAAATTGCTTCACCATTTTATCTCATGTATTTCGACTATCACGAATCATTCGTGAGCACTATGTCATAATATTGTAGTAAATAAGATCTG',
    ),
    ReferenceRecord(
      id: 'REF024',
      scientificName: 'Aspergillus niger',
      commonName: 'Black mold',
      lineage:
          'Eukaryota;Fungi;Ascomycota;Eurotiomycetes;Eurotiales;Aspergillaceae;Aspergillus;Aspergillus niger',
      markerGene: 'ITS',
      sequence:
          'TAGAGATGTTCAGAAAAAATAGAATAGGCTAGGTGAAACGAATTACATGGAACCCATCATGGTCGCAGGCATTCACTCGCGTCAATCTTTAATCTTTACTTACTGGTTAAGCCGCGCGTATATGCACCCAGGCAGGAGCACATTAGGCAATCTACAGCCTCGATCATGTAGGTGAGACCATAAACATATAAAATGGATTGGTGCTGACTATATATATTGTTAAGGCTTGTGCGCGTGACGTGGGAGGGTGTTGGCTTGAG',
    ),
    ReferenceRecord(
      id: 'REF025',
      scientificName: 'Candida albicans',
      commonName: 'Candida',
      lineage:
          'Eukaryota;Fungi;Ascomycota;Saccharomycetes;Saccharomycetales;Debaryomycetaceae;Candida;Candida albicans',
      markerGene: 'ITS',
      sequence:
          'GGTTCTTAGGACGTGTATTGTAGGAAAGATAGTTGCTGTGCGTCACAGATGAGAGTATATAGAACACTACCTTTTGTATGGCTCGCACATCAGTTTTTATGGGGTACACCGGAATAAGGTGTTATGCGATTGCGGAGAACCTCTTGGCAACTTGTTGTTGGACTGCCGGGATTTCTACCC',
    ),
    ReferenceRecord(
      id: 'REF026',
      scientificName: 'Penicillium chrysogenum',
      commonName: 'Penicillium mold',
      lineage:
          'Eukaryota;Fungi;Ascomycota;Eurotiomycetes;Eurotiales;Aspergillaceae;Penicillium;Penicillium chrysogenum',
      markerGene: 'ITS',
      sequence:
          'AATCAGAGTAGACCATCGCCGGCCCTTCCAATAATCCCGGTGACCCGAGTATCCAGGTCTGTCGTGAGCAGGCCTTCTCATATACTAAACAGAACATACTAGCTCATAGACACAATATGATATGTAAATATATTCGGCGACACCAGTTGATAGTACCCGGTGACCCATGCGCGAAGGCTCCTGCCCAGGCGTCAGTTGTT',
    ),
    ReferenceRecord(
      id: 'REF027',
      scientificName: 'Severe acute respiratory syndrome coronavirus 2',
      commonName: 'SARS-CoV-2',
      lineage:
          'Viruses;Riboviria;Orthornavirae;Pisuviricota;Pisoniviricetes;Nidovirales;Coronaviridae',
      markerGene: 'Spike (S) gene',
      sequence:
          'GAACCTATTGAAGTGTATGTACAACTGTCACATACTTTGGAAGTCGGAGGGCCCTGGAAAAGGCTTCGCCGAAGTGCTAGACTTCATGCAAGAATACTATACAACGGCCGAGCCCGCAAAGAAAGAATCGTGGCCGTCAGAGGGTCGAGGCAAGCCCGAAGTCGTGGTGTCGTGGCCCCAATGGTATTCTAGAGCGTGGCCCGCCTAGTGTCGTCTCATT',
    ),
    ReferenceRecord(
      id: 'REF028',
      scientificName: 'Influenza A virus',
      commonName: 'Flu A virus',
      lineage:
          'Viruses;Riboviria;Orthornavirae;Negarnaviricota;Polyploviricotina;Insthoviricetes;Articulavirales;Orthomyxoviridae',
      markerGene: 'Hemagglutinin (HA)',
      sequence:
          'GTCGCCTTTATAAATTTACAATGGAATAAAGACCGACTCATAAATATTGTATAGTAGCCCTAGATTTCGACGCTATCCCAATTTTAAACATATCTCTCAAGATCCATGCACGTTCTTAGAGCTAAGTATTTTATAAGAACGTTATCTTTTGAAAGGGCACGATTTATACGATATAAAAAGCCACGTTATAGAGGATTAAGGTTGGGTAAGAGACAGAGTAAACGCTTGTACTCACGACAA',
    ),
    ReferenceRecord(
      id: 'REF029',
      scientificName: 'Human immunodeficiency virus 1',
      commonName: 'HIV-1',
      lineage:
          'Viruses;Riboviria;Pararnavirae;Artverviricota;Revtraviricetes;Ortervirales;Retroviridae;Lentivirus',
      markerGene: 'pol gene',
      sequence:
          'CTTTCAGCGTAAAATTATGCTTTTTACAATGAATGTGAGATTTTTCATTCTTACGATTGTTGCTACATTAAGTGTCCTCTGTATCACTTTATGTATTCGCAGCATAAGGCTGCTACTGAAACTTTTAATCTTATAGAGGAGGACTGTAGTTTAATTTCGTGAACATAATTAGCATAACAAAAAATAAAGCATATCATGTGCAACTATGATTGCAAATTACCACAGATAGATATTTAGATCCTTAACAGAGCTACGTGTCC',
    ),
    ReferenceRecord(
      id: 'REF030',
      scientificName: 'Plasmodium falciparum',
      commonName: 'Malaria parasite',
      lineage:
          'Eukaryota;Protista;Apicomplexa;Aconoidasida;Haemosporida;Plasmodiidae;Plasmodium;Plasmodium falciparum',
      markerGene: '18S rRNA',
      sequence:
          'ACACTAATAAGTTTCAATGACACAGCGTTAAAACGATTCGTTGTGTTTATCGGATCATACTTAACCTTCAATTGAATTTTATCTGGTTTAGTGTATCGATCTGTCCGGCCGTGCACGCTGACCCTCCAGGAGTTAACTCTAAAAACAGATTGACCACAACTAAAAGCATGTTTATTATAG',
    ),
    ReferenceRecord(
      id: 'REF031',
      scientificName: 'Escherichia coli O157:H7',
      commonName: 'E. coli O157:H7',
      lineage:
          'Bacteria;Proteobacteria;Gammaproteobacteria;Enterobacterales;Enterobacteriaceae;Escherichia;Escherichia coli O157:H7',
      markerGene: '16S rRNA',
      sequence:
          'CCAAGAGACCTGCGTGATTATAAGGCTAAATGTGAGGTAATTACCGCTGATTTAGTGATGTGCGTAATACTAATCAATCCATCACTGACAACCATTACATCTAGGGAATTACGAAACAAAGAAATCACTCCCTGACCTCAAGGAAGGTAAAAACAAAAACTGCACTCTGATGGTAATCCTTCCGAAATTCGACTACTATC',
    ),
    ReferenceRecord(
      id: 'REF032',
      scientificName: 'Anopheles gambiae',
      commonName: 'Malaria mosquito',
      lineage:
          'Eukaryota;Animalia;Arthropoda;Insecta;Diptera;Culicidae;Anopheles;Anopheles gambiae',
      markerGene: 'COI (mtDNA)',
      sequence:
          'GTGCCAGGCCGCTATTCATCCATTTCAGGTTTGCGGGTAAACACTAGGGCATAACGGCATTTCATGGTCCCTGAAGTCGCCTGCTCCCAACCCATAGCACTCGTGCTGCATCGAGACCGCCTTGAGTTCACACCAGATTTGCTGGCTATTTCGCTACGCCACTATGGAAAATGGCGCATTCCCTAACTCAAACGGGAGGAATTACCAGGGATCCTATACC',
    ),
    ReferenceRecord(
      id: 'REF033',
      scientificName: 'Xenopus laevis',
      commonName: 'African clawed frog',
      lineage:
          'Eukaryota;Animalia;Chordata;Amphibia;Anura;Pipidae;Xenopus;Xenopus laevis',
      markerGene: 'COI (mtDNA)',
      sequence:
          'CGGCCAGGAGTAGTCCAAGCCCATTATAGTGCACGCCGGCTCCATGCATCTCCGGGACTTATTCCAGCCCTTGGTTCACCTCCCCTCGCCCAGCGAAATGCGATACTGTTAGCGAAATCGACCCATTGTGTGGCGATGAATGCGCTGCAAGAAACTAGTACCTTAAGTCTAGAATGTAGAGTCCTAGCGTGGCGAATCTCCGTTTAAGGTTATTCGGGTGGTGACGGAACTTATGCATCG',
    ),
    ReferenceRecord(
      id: 'REF034',
      scientificName: 'Caenorhabditis elegans',
      commonName: 'Roundworm',
      lineage:
          'Eukaryota;Animalia;Nematoda;Chromadorea;Rhabditida;Rhabditidae;Caenorhabditis;Caenorhabditis elegans',
      markerGene: '18S rRNA',
      sequence:
          'GAAGGACGATACTGGGAAATCCCTCATAGTGCAAGGTGCCGGTCGTGTCCGCCTTAAGTGTGATGGCGCAGCCGAATGCTCATCGTGGCGTACTTAAACAGCTAAACACCTCGAGATATGCTCCAGGGCGGGAGGGCGAGGTCCGCAGCCCATTGTCTGGCAAAGTGGTTGGGCCTGTCCATGCGACCGAATGTGGTTGAAAAGGAGTTACGCATAACTTCTCAGGCCGTGCAGTACCACTCCGTCGAGTGGGGTTCGCT',
    ),
    ReferenceRecord(
      id: 'REF035',
      scientificName: 'Thermus aquaticus',
      commonName: 'Thermophilic bacterium',
      lineage:
          'Bacteria;Deinococcus-Thermus;Deinococci;Thermales;Thermaceae;Thermus;Thermus aquaticus',
      markerGene: '16S rRNA',
      sequence:
          'AACACAACAAGATGTTACTGGGCGATATCGTTCCAACATAACATTTGGGGCTATTTAAAGTTAATATACATGTCTAGATTACTTGCATTCCACGTGTATATTAGTTTGAGCCCTTTCAAGTATTTTCAATACCAACTACTTTAGGTTACTTTTTAACTTTAGATAAACAAATAAATTTAT',
    ),
    // --- Archaea (Domain of life not otherwise represented above) ---
    ReferenceRecord(
      id: 'REF036',
      scientificName: 'Methanocaldococcus jannaschii',
      commonName: 'Deep-sea hyperthermophilic methanogen',
      lineage:
          'Archaea;Euryarchaeota;Methanococci;Methanococcales;Methanocaldococcaceae;Methanocaldococcus;Methanocaldococcus jannaschii',
      markerGene: '16S rRNA',
      sequence:
          'GGCTCAGTAACACGTGGATAACCTGCCCTTAAGACTGGGATAACTCCGGGAAACCGGAGCTAATACCGGATAATATTTTGAACCGCATGGTTCAAAAGTGAAAGACGGTCTTGCTGTCACTTATAGATGGATCCGCGCCGTATTAGCTAGTTGGTAAGGTAACGGCTTACCAAGGCGACGATACGTAGCCGACCTGAGAGGGTGATCGGCCACACTGGAACTGAGACACGGTCCAGACTCCTACGGG',
    ),
    ReferenceRecord(
      id: 'REF037',
      scientificName: 'Halobacterium salinarum',
      commonName: 'Extreme halophilic archaeon',
      lineage:
          'Archaea;Euryarchaeota;Halobacteria;Halobacteriales;Halobacteriaceae;Halobacterium;Halobacterium salinarum',
      markerGene: '16S rRNA',
      sequence:
          'TTCCGGTTGATCCTGCCGGACCCGACCGCTATCGGGGTGGGGATAACCCCGGGAAACTGGGGCTAATACCGCATAACGTCGCAAGACCAAAGTGGGGGACCTTCGGGCCTCACGCCATCAGATGTGCCCAGATGGGATTAGCTAGTAGGTGGGGTAACGGCTCACCTAGGCGACGATCCCTAGCTGGTCTGAGAGGATGACCAGCCACACTGGGACTGAGACACGGCCCAGACTCCTACGGGAGG',
    ),
    ReferenceRecord(
      id: 'REF038',
      scientificName: 'Sulfolobus solfataricus',
      commonName: 'Thermoacidophilic archaeon',
      lineage:
          'Archaea;Crenarchaeota;Thermoprotei;Sulfolobales;Sulfolobaceae;Sulfolobus;Sulfolobus solfataricus',
      markerGene: '16S rRNA',
      sequence:
          'AGAGTTTGATCCTGGCTCAGGATGAACGCTGGCGGCGTGCTTAACACATGCAAGTCGAACGAGACCTTCGGGTCTAGTGGCGGACGGGTGAGTAACACGTGAGCAACCTGCCCTCAGGTGGGGGATAACCCCGGGAAACCGGGGCTAATACCGGATAATCCCTTCCCTCACATGAGGGAAGATTAAAAGATGGCTTCGGCTATCACTTACAGATGGGCCCGCGGCGCATTAGCTAGTTGGT',
    ),
  ];
}
