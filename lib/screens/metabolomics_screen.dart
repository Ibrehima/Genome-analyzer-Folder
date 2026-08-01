import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/analysis_models.dart';
import '../engines/metabolomics_engine.dart';
import '../engines/export/report_data.dart';
import '../utils/app_theme.dart';
import '../widgets/export_menu_button.dart';

/// Offline metabolomics triage module: chemical-formula mass calculator,
/// a curated small-molecule (metabolite) explorer, and mass-based (MS-style)
/// candidate identification against the curated local database.
///
/// HONESTY NOTE (also shown in-app): the formula-mass math uses real,
/// standard atomic-weight / monoisotopic-mass constants and is exact for
/// the formula entered. The metabolite database itself is a small curated
/// demonstration set (32 common central-carbon / amino-acid / lipid
/// metabolites) — NOT a replacement for KEGG, HMDB, PubChem or
/// MetaboAnalyst, and mass-based matching here is a coarse triage step,
/// not MS/MS-confirmed identification.
class MetabolomicsScreen extends StatefulWidget {
  const MetabolomicsScreen({super.key});

  @override
  State<MetabolomicsScreen> createState() => _MetabolomicsScreenState();
}

class _MetabolomicsScreenState extends State<MetabolomicsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Formula calculator state ---
  final _formulaCtrl = TextEditingController(text: 'C6H12O6');
  FormulaMassResult? _formulaResult;

  // --- Explorer state ---
  final _searchCtrl = TextEditingController();
  String? _classFilter;
  List<MetaboliteRecord> _explorerResults = MetabolomicsEngine.search('');

  // --- Mass ID state ---
  final _massCtrl = TextEditingController(text: '181.0703');
  String _adduct = '[M+H]+';
  double _tolerancePpm = 20;
  List<MassSearchMatch> _massMatches = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _computeFormula();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _formulaCtrl.dispose();
    _searchCtrl.dispose();
    _massCtrl.dispose();
    super.dispose();
  }

  void _computeFormula() {
    final f = _formulaCtrl.text.trim();
    if (f.isEmpty) {
      setState(() => _formulaResult = null);
      return;
    }
    setState(() => _formulaResult = MetabolomicsEngine.computeMass(f));
  }

  void _runExplorerSearch() {
    var results = MetabolomicsEngine.search(_searchCtrl.text);
    if (_classFilter != null) {
      results = results
          .where((m) => m.metaboliteClass == _classFilter)
          .toList();
    }
    setState(() => _explorerResults = results);
  }

  void _runMassSearch() {
    final mass = double.tryParse(_massCtrl.text.trim());
    if (mass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid numeric mass (Da).')),
      );
      return;
    }
    setState(() {
      _massMatches = MetabolomicsEngine.searchByMass(
        mass,
        adduct: _adduct,
        tolerancePpm: _tolerancePpm,
      );
    });
  }

  Future<void> _openSearch(String site, String query) async {
    final q = Uri.encodeComponent(query);
    String url;
    switch (site) {
      case 'KEGG':
        url =
            'https://www.genome.jp/kegg-bin/search?keyword=$q&mode=1&category=compound';
        break;
      case 'HMDB':
        url = 'https://hmdb.ca/unearth/q?query=$q&searcher=metabolites';
        break;
      default:
        url = 'https://pubchem.ncbi.nlm.nih.gov/#query=$q';
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    }
  }

  ReportData _buildReport() {
    final sections = <ReportSection>[];
    if (_formulaResult != null) {
      final r = _formulaResult!;
      sections.add(
        ReportSection(
          title: 'Formula Mass Calculation',
          table: [
            ['Property', 'Value'],
            ['Formula', r.formula],
            [
              'Average molecular weight',
              '${r.averageMassDa.toStringAsFixed(3)} Da',
            ],
            [
              'Monoisotopic mass',
              '${r.monoisotopicMassDa.toStringAsFixed(4)} Da',
            ],
            [
              'Elemental composition',
              r.elementCounts.entries
                  .map((e) => '${e.key}${e.value}')
                  .join(' '),
            ],
          ],
        ),
      );
    }
    if (_massMatches.isNotEmpty) {
      sections.add(
        ReportSection(
          title: 'Mass-Based Candidate Matches',
          table: [
            ['Metabolite', 'Class', 'Theoretical mass (Da)', 'Δppm', 'Adduct'],
            ..._massMatches.map(
              (m) => [
                m.metabolite.name,
                m.metabolite.metaboliteClass,
                m.theoreticalMass.toStringAsFixed(4),
                m.deltaPpm.toStringAsFixed(1),
                m.adduct,
              ],
            ),
          ],
        ),
      );
    }
    sections.add(
      ReportSection(
        title: 'Disclaimer',
        bodyText:
            'Formula-mass calculations use standard IUPAC atomic-weight / '
            'monoisotopic-mass constants (exact for the formula entered). '
            'The metabolite database is a small (32-entry) curated '
            'demonstration set — for comprehensive, authoritative metabolite '
            'identification use KEGG, HMDB, PubChem, or MS/MS-based tools '
            'such as MetaboAnalyst / GNPS.',
      ),
    );
    return ReportData(title: 'Metabolomics Report', sections: sections);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metabolomics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Formula Mass'),
            Tab(text: 'Explorer'),
            Tab(text: 'Mass ID'),
          ],
        ),
        actions: [
          ExportMenuButton(
            reportBuilder: _buildReport,
            moduleType: 'Metabolomics',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gradMetabolomics.first.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gradMetabolomics.first.withValues(
                    alpha: 0.25,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.gradMetabolomics.first,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Formula-mass math uses real atomic-weight constants (exact). The '
                      'metabolite database is a small curated demonstration set — for '
                      'authoritative data use KEGG / HMDB / PubChem / MetaboAnalyst.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFormulaTab(),
                _buildExplorerTab(),
                _buildMassIdTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaTab() {
    final r = _formulaResult;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: [
        TextField(
          controller: _formulaCtrl,
          decoration: const InputDecoration(
            labelText: 'Chemical formula (e.g. C6H12O6, C10H16N5O13P3)',
          ),
          onChanged: (_) => _computeFormula(),
        ),
        const SizedBox(height: 16),
        if (r != null) ...[
          if (r.elementCounts.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Could not parse any recognized elements from this formula.',
                style: TextStyle(fontSize: 12.5),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Elemental Composition',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: r.elementCounts.entries
                          .map(
                            (e) => Chip(
                              label: Text('${e.key}${e.value}'),
                              backgroundColor: AppColors.gradMetabolomics.first
                                  .withValues(alpha: 0.12),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        _metric(
                          'Average MW',
                          '${r.averageMassDa.toStringAsFixed(2)} Da',
                          AppColors.gradMetabolomics.first,
                        ),
                        _metric(
                          'Monoisotopic mass',
                          '${r.monoisotopicMassDa.toStringAsFixed(4)} Da',
                          AppColors.primaryBlue,
                        ),
                      ],
                    ),
                    if (!MetabolomicsEngine.isFormulaFullyRecognized(
                      r.formula,
                    )) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Note: one or more symbols in this formula were not recognized '
                        'and were ignored in the mass calculation.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildExplorerTab() {
    final classes = MetabolomicsEngine.allClasses();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: 'Search by name, formula, class or pathway',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _runExplorerSearch,
                  ),
                ),
                onSubmitted: (_) => _runExplorerSearch(),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _classFilter == null,
                        onSelected: (_) {
                          setState(() => _classFilter = null);
                          _runExplorerSearch();
                        },
                      ),
                    ),
                    ...classes.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: _classFilter == c,
                          onSelected: (_) {
                            setState(() => _classFilter = c);
                            _runExplorerSearch();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
            itemCount: _explorerResults.length,
            itemBuilder: (context, i) {
              final m = _explorerResults[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gradMetabolomics.first
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              m.formula,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${m.metaboliteClass} · ${m.pathway}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        m.description,
                        style: const TextStyle(fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _openSearch('KEGG', m.name),
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text(
                              'KEGG',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _openSearch('HMDB', m.name),
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text(
                              'HMDB',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _openSearch('PubChem', m.name),
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text(
                              'PubChem',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMassIdTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: [
        TextField(
          controller: _massCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Observed mass (Da)'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Adduct: ', style: TextStyle(fontSize: 12.5)),
            DropdownButton<String>(
              value: _adduct,
              items: MetabolomicsEngine.supportedAdducts
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (v) => setState(() => _adduct = v ?? _adduct),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Tolerance: ', style: TextStyle(fontSize: 12.5)),
            Expanded(
              child: Slider(
                value: _tolerancePpm,
                min: 5,
                max: 100,
                divisions: 19,
                label: '${_tolerancePpm.toStringAsFixed(0)} ppm',
                onChanged: (v) => setState(() => _tolerancePpm = v),
              ),
            ),
            Text(
              '${_tolerancePpm.toStringAsFixed(0)} ppm',
              style: const TextStyle(fontSize: 12.5),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _runMassSearch,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Search Candidate Metabolites'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Classic MS-style triage: ranks curated metabolites whose theoretical '
          'adduct mass falls within tolerance of the observed mass. Not a '
          'substitute for MS/MS fragmentation or retention-time confirmation.',
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        if (_massMatches.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'No matches yet — run a search above.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          )
        else
          ..._massMatches.map(
            (m) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.metabolite.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${m.metabolite.formula} · theoretical ${m.theoreticalMass.toStringAsFixed(4)} Da (${m.adduct})',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (m.deltaPpm.abs() < 5
                                    ? AppColors.success
                                    : AppColors.warning)
                                .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${m.deltaPpm >= 0 ? '+' : ''}${m.deltaPpm.toStringAsFixed(1)} ppm',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: m.deltaPpm.abs() < 5
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 10.5, color: color)),
        ],
      ),
    );
  }
}
