import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bio_sequence.dart';
import '../models/analysis_models.dart';
import '../engines/rna_engine.dart';
import '../engines/sequence_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/colored_sequence_view.dart';
import '../widgets/export_menu_button.dart';

class RnaAnalysisScreen extends StatefulWidget {
  const RnaAnalysisScreen({super.key});

  @override
  State<RnaAnalysisScreen> createState() => _RnaAnalysisScreenState();
}

class _RnaAnalysisScreenState extends State<RnaAnalysisScreen> {
  String? _selectedId;
  bool _templateStrand = false;
  String? _rnaSequence;
  String? _rnaName;
  RnaClassificationResult? _classification;
  RnaFoldResult? _fold;
  bool _running = false;

  void _prepareAndRun(BioSequence seq) {
    setState(() => _running = true);
    String rna;
    if (seq.type == SequenceType.dna) {
      rna = _templateStrand
          ? RnaEngine.transcribeFromTemplateStrand(seq.sequence)
          : RnaEngine.transcribeCodingStrand(seq.sequence);
    } else {
      rna = seq.sequence.toUpperCase().replaceAll('T', 'U');
    }
    final classification = RnaEngine.classify(rna);
    final fold = RnaEngine.predictSecondaryStructure(rna);
    setState(() {
      _rnaSequence = rna;
      _rnaName = seq.name;
      _classification = classification;
      _fold = fold;
      _running = false;
    });
  }

  ReportData _buildReport() {
    final c = _classification;
    final f = _fold;
    if (c == null || f == null || _rnaSequence == null) {
      return ReportData(title: 'RNA Analysis Report');
    }
    return ReportData(
      title: 'RNA Analysis Report',
      subtitle: _rnaName ?? '',
      sections: [
        ReportSection(
          title: 'Transcription',
          bodyText: 'mRNA sequence (5\'->3\'):\n$_rnaSequence',
        ),
        ReportSection(
          title: 'RNA Class Identification (heuristic)',
          table: [
            ['Property', 'Value'],
            ['Predicted class', c.guess.label],
            ['Confidence', '${c.confidence.toStringAsFixed(0)}%'],
            [
              'Poly-A tail',
              c.hasPolyATail ? '${c.polyALength} nt' : 'Not detected',
            ],
            ['ORF / coding potential', c.hasOrf ? 'Detected' : 'Not detected'],
          ],
          bullets: c.reasons,
        ),
        ReportSection(
          title: 'Secondary Structure (Nussinov base-pair maximization)',
          bodyText:
              'Dot-bracket notation:\n${f.dotBracket}\n\nBase pairs formed: ${f.pairCount}\n'
              'NOTE: this is a simplified maximum base-pairing estimate, not a '
              'full thermodynamic free-energy fold (e.g. ViennaRNA/mfold).',
        ),
      ],
    );
  }

  Color _confidenceColor(double c) {
    if (c >= 60) return AppColors.success;
    if (c >= 35) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selectedSeq = _selectedId != null
        ? appState.getSequenceById(_selectedId!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RNA Analysis'),
        actions: [
          if (_classification != null)
            ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: 'RNA Analysis',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          SequenceSelector(
            selectedIds: _selectedId != null ? [_selectedId!] : [],
            multiple: false,
            onChanged: (v) => setState(() {
              _selectedId = v.isNotEmpty ? v.first : null;
              _classification = null;
              _fold = null;
            }),
            label: 'Select a DNA or RNA sequence',
          ),
          if (selectedSeq != null && selectedSeq.type == SequenceType.dna) ...[
            const SizedBox(height: 14),
            const Text(
              'Which strand is provided?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Coding (sense) strand'),
                  icon: Icon(Icons.arrow_forward),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Template (antisense) strand'),
                  icon: Icon(Icons.compare_arrows),
                ),
              ],
              selected: {_templateStrand},
              onSelectionChanged: (v) =>
                  setState(() => _templateStrand = v.first),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedSeq == null || _running
                  ? null
                  : () => _prepareAndRun(selectedSeq),
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.biotech),
              label: Text(
                _running ? 'Analyzing...' : 'Transcribe & Analyze RNA',
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_classification != null && _fold != null && _rnaSequence != null)
            _RnaResultView(
              rnaSequence: _rnaSequence!,
              classification: _classification!,
              fold: _fold!,
              confidenceColor: _confidenceColor,
            ),
        ],
      ),
    );
  }
}

class _RnaResultView extends StatelessWidget {
  final String rnaSequence;
  final RnaClassificationResult classification;
  final RnaFoldResult fold;
  final Color Function(double) confidenceColor;

  const _RnaResultView({
    required this.rnaSequence,
    required this.classification,
    required this.fold,
    required this.confidenceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'mRNA sequence (5\'->3\')',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ColoredSequenceView(sequence: rnaSequence, fontSize: 12),
                const SizedBox(height: 6),
                Text(
                  '${rnaSequence.length} nt · GC ${SequenceEngine.gcContent(rnaSequence).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        classification.guess.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: confidenceColor(
                          classification.confidence,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${classification.confidence.toStringAsFixed(0)}% confidence',
                        style: TextStyle(
                          color: confidenceColor(classification.confidence),
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: classification.confidence / 100,
                    minHeight: 6,
                    color: confidenceColor(classification.confidence),
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
                const SizedBox(height: 12),
                ...classification.reasons.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(r, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
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
                  'Secondary Structure (simplified)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Nussinov base-pair maximization — indicative fold, not a full thermodynamic prediction.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    fold.dotBracket,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: [
                    Chip(label: Text('${fold.pairCount} base pairs')),
                    Chip(
                      label: Text(
                        'Score: ${fold.pseudoFreeEnergy.toStringAsFixed(1)}',
                      ),
                    ),
                    Chip(label: Text('${fold.sequence.length} nt analyzed')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
