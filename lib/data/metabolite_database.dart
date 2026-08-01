import '../models/analysis_models.dart';

/// Curated local small-molecule (metabolite) database used for offline
/// metabolomics triage: molecular-formula lookups, class/pathway browsing,
/// and mass-based identification. NOTE: molecular formulas below are
/// standard, well-established textbook formulas (glycolysis/TCA cycle
/// intermediates, common amino acids, nucleotides, etc.) — this is a small
/// curated demonstration set, NOT a replacement for KEGG, HMDB, PubChem or
/// MetaboAnalyst, which should be used for authoritative structures,
/// pathway maps and spectral confirmation (see the in-app deep links).
class MetaboliteDatabase {
  static final List<MetaboliteRecord> records = [
    MetaboliteRecord(
      id: 'MET001',
      name: 'Glucose',
      formula: 'C6H12O6',
      metaboliteClass: 'Carbohydrate',
      pathway: 'Glycolysis',
      description: 'Primary cellular fuel; entry point of glycolysis.',
    ),
    MetaboliteRecord(
      id: 'MET002',
      name: 'Fructose',
      formula: 'C6H12O6',
      metaboliteClass: 'Carbohydrate',
      pathway: 'Fructose metabolism / Glycolysis',
      description: 'Dietary sugar isomer of glucose, feeds into glycolysis.',
    ),
    MetaboliteRecord(
      id: 'MET003',
      name: 'Pyruvate',
      formula: 'C3H4O3',
      metaboliteClass: 'Organic acid',
      pathway: 'Glycolysis / TCA cycle entry',
      description:
          'End product of glycolysis; converted to acetyl-CoA or lactate.',
    ),
    MetaboliteRecord(
      id: 'MET004',
      name: 'Lactate',
      formula: 'C3H6O3',
      metaboliteClass: 'Organic acid',
      pathway: 'Anaerobic glycolysis',
      description:
          'Produced from pyruvate under low-oxygen conditions (e.g. muscle exertion).',
    ),
    MetaboliteRecord(
      id: 'MET005',
      name: 'Citrate',
      formula: 'C6H8O7',
      metaboliteClass: 'Organic acid',
      pathway: 'TCA cycle',
      description:
          'First stable intermediate of the citric acid (Krebs) cycle.',
    ),
    MetaboliteRecord(
      id: 'MET006',
      name: 'Succinate',
      formula: 'C4H6O4',
      metaboliteClass: 'Organic acid',
      pathway: 'TCA cycle',
      description:
          'TCA cycle intermediate; oxidized by succinate dehydrogenase (Complex II).',
    ),
    MetaboliteRecord(
      id: 'MET007',
      name: 'Fumarate',
      formula: 'C4H4O4',
      metaboliteClass: 'Organic acid',
      pathway: 'TCA cycle',
      description: 'TCA cycle intermediate produced from succinate.',
    ),
    MetaboliteRecord(
      id: 'MET008',
      name: 'Malate',
      formula: 'C4H6O5',
      metaboliteClass: 'Organic acid',
      pathway: 'TCA cycle',
      description: 'TCA cycle intermediate; converted to oxaloacetate.',
    ),
    MetaboliteRecord(
      id: 'MET009',
      name: 'Oxaloacetate',
      formula: 'C4H4O5',
      metaboliteClass: 'Organic acid',
      pathway: 'TCA cycle',
      description:
          'Combines with acetyl-CoA to regenerate citrate, closing the TCA cycle.',
    ),
    MetaboliteRecord(
      id: 'MET010',
      name: 'alpha-Ketoglutarate',
      formula: 'C5H6O5',
      metaboliteClass: 'Organic acid',
      pathway: 'TCA cycle / Amino acid metabolism',
      description:
          'TCA cycle intermediate and key nitrogen-transfer hub (transamination).',
    ),
    MetaboliteRecord(
      id: 'MET011',
      name: 'ATP',
      formula: 'C10H16N5O13P3',
      metaboliteClass: 'Nucleotide',
      pathway: 'Energy metabolism',
      description: 'Primary cellular energy currency (adenosine triphosphate).',
    ),
    MetaboliteRecord(
      id: 'MET012',
      name: 'ADP',
      formula: 'C10H15N5O10P2',
      metaboliteClass: 'Nucleotide',
      pathway: 'Energy metabolism',
      description:
          'Adenosine diphosphate; regenerated to ATP via oxidative phosphorylation.',
    ),
    MetaboliteRecord(
      id: 'MET013',
      name: 'AMP',
      formula: 'C10H14N5O7P',
      metaboliteClass: 'Nucleotide',
      pathway: 'Energy metabolism / Nucleotide metabolism',
      description:
          'Adenosine monophosphate; energy-charge / AMPK signaling indicator.',
    ),
    MetaboliteRecord(
      id: 'MET014',
      name: 'NAD+',
      formula: 'C21H27N7O14P2',
      metaboliteClass: 'Cofactor',
      pathway: 'Redox metabolism',
      description:
          'Key redox cofactor (oxidized form) shuttling electrons in catabolism.',
    ),
    MetaboliteRecord(
      id: 'MET015',
      name: 'Urea',
      formula: 'CH4N2O',
      metaboliteClass: 'Nitrogen waste product',
      pathway: 'Urea cycle',
      description:
          'Major excreted nitrogen-waste product of amino-acid catabolism.',
    ),
    MetaboliteRecord(
      id: 'MET016',
      name: 'Creatinine',
      formula: 'C4H7N3O',
      metaboliteClass: 'Nitrogen waste product',
      pathway: 'Muscle / creatine metabolism',
      description:
          'Breakdown product of creatine phosphate; standard renal-function marker.',
    ),
    MetaboliteRecord(
      id: 'MET017',
      name: 'Creatine',
      formula: 'C4H9N3O2',
      metaboliteClass: 'Amino-acid derivative',
      pathway: 'Energy buffering (phosphocreatine system)',
      description:
          'Buffers cellular ATP levels via the creatine phosphate shuttle.',
    ),
    MetaboliteRecord(
      id: 'MET018',
      name: 'Uric acid',
      formula: 'C5H4N4O3',
      metaboliteClass: 'Purine catabolite',
      pathway: 'Purine metabolism',
      description:
          'Final oxidation product of purine (adenine/guanine) breakdown in humans.',
    ),
    MetaboliteRecord(
      id: 'MET019',
      name: 'Glycine',
      formula: 'C2H5NO2',
      metaboliteClass: 'Amino acid',
      pathway: 'Protein synthesis / One-carbon metabolism',
      description:
          'Smallest amino acid; also a precursor for glutathione, heme and purines.',
    ),
    MetaboliteRecord(
      id: 'MET020',
      name: 'Alanine',
      formula: 'C3H7NO2',
      metaboliteClass: 'Amino acid',
      pathway: 'Amino acid metabolism / Glucose-alanine cycle',
      description:
          'Shuttles nitrogen from muscle to liver (glucose-alanine cycle).',
    ),
    MetaboliteRecord(
      id: 'MET021',
      name: 'Glutamate',
      formula: 'C5H9NO4',
      metaboliteClass: 'Amino acid',
      pathway: 'Amino acid metabolism / Neurotransmission',
      description:
          'Central hub of amino-acid nitrogen metabolism; major excitatory neurotransmitter.',
    ),
    MetaboliteRecord(
      id: 'MET022',
      name: 'Glutamine',
      formula: 'C5H10N2O3',
      metaboliteClass: 'Amino acid',
      pathway: 'Nitrogen transport',
      description:
          'Main carrier of ammonia between tissues; abundant free amino acid in blood.',
    ),
    MetaboliteRecord(
      id: 'MET023',
      name: 'Serine',
      formula: 'C3H7NO3',
      metaboliteClass: 'Amino acid',
      pathway: 'One-carbon (folate) metabolism',
      description:
          'Precursor for glycine, cysteine, and one-carbon units used in nucleotide synthesis.',
    ),
    MetaboliteRecord(
      id: 'MET024',
      name: 'Cholesterol',
      formula: 'C27H46O',
      metaboliteClass: 'Lipid (sterol)',
      pathway: 'Steroid / membrane lipid metabolism',
      description:
          'Membrane lipid and precursor of steroid hormones and bile acids.',
    ),
    MetaboliteRecord(
      id: 'MET025',
      name: 'Palmitic acid',
      formula: 'C16H32O2',
      metaboliteClass: 'Fatty acid',
      pathway: 'Fatty acid metabolism',
      description:
          'Most common saturated fatty acid in the human body; energy storage/beta-oxidation.',
    ),
    MetaboliteRecord(
      id: 'MET026',
      name: 'Glycerol',
      formula: 'C3H8O3',
      metaboliteClass: 'Lipid backbone',
      pathway: 'Lipid metabolism / Gluconeogenesis',
      description:
          'Triglyceride backbone released during lipolysis; gluconeogenic substrate.',
    ),
    MetaboliteRecord(
      id: 'MET027',
      name: 'Ethanol',
      formula: 'C2H6O',
      metaboliteClass: 'Small alcohol',
      pathway: 'Alcohol metabolism',
      description:
          'Metabolized to acetaldehyde then acetate via alcohol/aldehyde dehydrogenase.',
    ),
    MetaboliteRecord(
      id: 'MET028',
      name: 'Acetate',
      formula: 'C2H4O2',
      metaboliteClass: 'Short-chain fatty acid',
      pathway: 'Fatty-acid synthesis / short-chain fatty acid metabolism',
      description:
          'Simple 2-carbon acid; activated to acetyl-CoA for energy or lipid synthesis.',
    ),
    MetaboliteRecord(
      id: 'MET029',
      name: 'Dopamine',
      formula: 'C8H11NO2',
      metaboliteClass: 'Biogenic amine (catecholamine)',
      pathway: 'Tyrosine / catecholamine metabolism',
      description: 'Neurotransmitter derived from tyrosine via L-DOPA.',
    ),
    MetaboliteRecord(
      id: 'MET030',
      name: 'Serotonin',
      formula: 'C10H12N2O',
      metaboliteClass: 'Biogenic amine',
      pathway: 'Tryptophan metabolism',
      description: 'Neurotransmitter/hormone derived from tryptophan.',
    ),
    MetaboliteRecord(
      id: 'MET031',
      name: 'Histamine',
      formula: 'C5H9N3',
      metaboliteClass: 'Biogenic amine',
      pathway: 'Histidine metabolism',
      description:
          'Mediator of immune/allergic responses, derived from histidine decarboxylation.',
    ),
    MetaboliteRecord(
      id: 'MET032',
      name: 'Homocysteine',
      formula: 'C4H9NO2S',
      metaboliteClass: 'Sulfur amino acid',
      pathway: 'Methionine metabolism',
      description:
          'Intermediate of methionine metabolism; elevated levels linked to cardiovascular risk.',
    ),
  ];
}
