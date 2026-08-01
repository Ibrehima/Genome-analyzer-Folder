import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bio_sequence.dart';
import '../models/analysis_models.dart';
import '../engines/phylo_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/phylo_tree_view.dart';
import '../widgets/export_menu_button.dart';

class PhyloTreeScreen extends StatefulWidget {
  const PhyloTreeScreen({super.key});

  @override
  State<PhyloTreeScreen> createState() => _PhyloTreeScreenState();
}

class _PhyloTreeScreenState extends State<PhyloTreeScreen> {
  List<String> _selectedIds = [];
  String _method = 'UPGMA';
  bool _running = false;
  PhyloTreeResult? _tree;

  Future<void> _run() async {
    final appState = context.read<AppState>();
    final seqs = <BioSequence>[];
    for (final id in _selectedIds) {
      final s = appState.getSequenceById(id);
      if (s != null) seqs.add(s);
    }
    if (seqs.length < 3) return;
    setState(() => _running = true);
    await Future.delayed(const Duration(milliseconds: 50));
    final names = seqs.map((s) => s.name).toList();
    final sequences = seqs.map((s) => s.sequence).toList();
    final result = _method == 'UPGMA'
        ? PhyloEngine.buildUPGMA(names, sequences)
        : PhyloEngine.buildNeighborJoining(names, sequences);
    setState(() {
      _tree = result;
      _running = false;
    });
  }

  ReportData _buildReport() {
    final t = _tree!;
    return ReportData(
      title: 'Phylogenetic Tree Report',
      subtitle: '${t.method} · ${t.leafNames.length} taxa',
      sections: [
        ReportSection(
          title: 'Method',
          bodyText:
              '${t.method} tree was constructed from a pairwise distance matrix (p-distance for aligned sequences of equal length, '
              'k-mer Jaccard distance otherwise). Branch lengths are proportional to estimated evolutionary distance.',
        ),
        ReportSection(title: 'Taxa Included', bullets: t.leafNames),
        ReportSection(title: 'Newick Format Tree', bodyText: t.root.toNewick()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phylogenetic Tree'),
        actions: [
          if (_tree != null)
            ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: 'Phylogenetic Tree',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          SequenceSelector(
            selectedIds: _selectedIds,
            multiple: true,
            onChanged: (v) => setState(() => _selectedIds = v),
            label: 'Select 3+ sequences to build a tree',
          ),
          const SizedBox(height: 14),
          const Text(
            'Clustering method',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'UPGMA', label: Text('UPGMA')),
              ButtonSegment(value: 'NJ', label: Text('Neighbor-Joining')),
            ],
            selected: {_method == 'UPGMA' ? 'UPGMA' : 'NJ'},
            onSelectionChanged: (v) =>
                setState(() => _method = v.first == 'UPGMA' ? 'UPGMA' : 'NJ'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedIds.length < 3 || _running ? null : _run,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.account_tree_rounded),
              label: Text(_running ? 'Building tree...' : 'Build Tree'),
            ),
          ),
          const SizedBox(height: 20),
          if (_selectedIds.isNotEmpty && _selectedIds.length < 3)
            const _InfoBanner(
              text:
                  'Select at least 3 sequences to construct a meaningful phylogenetic tree.',
            ),
          if (_tree != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_tree!.method} Tree',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PhyloTreeView(tree: _tree!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Newick Format',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _tree!.root.toNewick(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tip: copy this Newick string into iTOL (Online Tools Hub) for advanced interactive visualization.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF7B1FA2)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}
