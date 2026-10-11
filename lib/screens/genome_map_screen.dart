import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../engines/sequence_engine.dart';
import '../engines/annotation_engine.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/genome_map_view.dart';
import '../widgets/project_switcher.dart';

/// Renders a sequence as an annotated genome map — circular (plasmid-style)
/// or linear (genome-browser-style) — plotting its ORFs/saved annotations
/// as positioned, numbered features on a scaled backbone.
class GenomeMapScreen extends StatefulWidget {
  const GenomeMapScreen({super.key});
  @override
  State<GenomeMapScreen> createState() => _GenomeMapScreenState();
}

class _GenomeMapScreenState extends State<GenomeMapScreen> {
  String? _selectedId;
  GenomeMapShape _shape = GenomeMapShape.circular;
  bool _includeOrfs = true;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final seq = _selectedId != null ? appState.getSequenceById(_selectedId!) : null;
    GenomeMapData? mapData;
    if (seq != null) {
      final features = <GenomeMapFeature>[];
      if (_includeOrfs) {
        final orfs = AnnotationEngine.findOrfs(seq.sequence, minLengthNt: 150);
        features.addAll(
          orfs
              .take(40)
              .map(
                (o) => GenomeMapFeature(
                  label: 'ORF (${o.length}nt)',
                  start: o.start,
                  end: o.end,
                  forwardStrand: o.forwardStrand,
                  category: 'ORF',
                ),
              ),
        );
      }
      final saved = appState.annotationsFor(seq.id);
      features.addAll(
        saved.map(
          (a) => GenomeMapFeature(
            label: a.label,
            start: a.start,
            end: a.end,
            forwardStrand: a.forwardStrand,
            category: a.featureType == 'CDS' ? 'CDS' : 'gene',
            note: a.note,
          ),
        ),
      );
      mapData = GenomeMapData(
        sequenceName: seq.name,
        sequenceLength: seq.length,
        gcContent: SequenceEngine.gcContent(seq.sequence),
        features: features,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Genome Map'),
        actions: [const ProjectSwitcher(), const SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gradGenomeMap.first.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFF004D40), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Visualize a sequence as a circular (plasmid-style) or '
                    'linear (genome-browser-style) map, with ORFs and saved '
                    'annotations plotted at their exact, numbered positions. '
                    'Use Mutation Detection to also plot SNPs/indels here.',
                    style: TextStyle(fontSize: 12, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SequenceSelector(
            selectedIds: _selectedId != null ? [_selectedId!] : [],
            onChanged: (v) => setState(() => _selectedId = v.isNotEmpty ? v.first : null),
            label: 'Select a sequence to map',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: GenomeMapShape.values
                      .map(
                        (s) => ChoiceChip(
                          label: Text(s.label),
                          selected: _shape == s,
                          onSelected: (_) => setState(() => _shape = s),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeOrfs,
            onChanged: (v) => setState(() => _includeOrfs = v),
            title: const Text(
              'Include ORFs (6-frame scan, >=150 nt)',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          if (mapData != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: GenomeMapView(data: mapData, shape: _shape),
              ),
            ),
            const SizedBox(height: 14),
            const GenomeMapLegend(),
            const SizedBox(height: 10),
            Text(
              '${mapData.features.length} feature(s) plotted on a ${mapData.sequenceLength} bp backbone.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
