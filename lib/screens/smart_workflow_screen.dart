import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bio_sequence.dart';
import '../models/workflow_result.dart';
import '../engines/export/report_data.dart';
import '../engines/quality_engine.dart';
import '../engines/identification_engine.dart';
import '../engines/primer_engine.dart';
import '../engines/annotation_engine.dart';
import '../engines/rna_engine.dart';
import '../engines/proteomics_engine.dart';
import '../engines/target_analysis_engine.dart';
import '../engines/statistics_engine.dart';
import '../engines/sequence_engine.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';
import 'my_results_screen.dart';

/// A single pluggable analysis task offered in the Smart Workflow checklist.
/// Each task turns one [BioSequence] into one or more [ReportSection]s so
/// that any combination of checked tasks can be concatenated into one
/// combined [ReportData] at the end of a sequential run.
class _WorkflowTask {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final List<ReportSection> Function(BioSequence seq) run;
  const _WorkflowTask({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.run,
  });
}

String _translatedProtein(BioSequence seq) {
  return seq.type == SequenceType.protein ? seq.sequence : SequenceEngine.translate(seq.sequence);
}

final List<_WorkflowTask> _availableTasks = [
  _WorkflowTask(
    id: 'quality',
    label: 'Quality Control',
    description: 'GC/AT/N content, Phred quality grade',
    icon: Icons.verified_rounded,
    run: (seq) {
      final r = QualityEngine.analyze(seq);
      return [
        ReportSection(
          title: 'Quality Control',
          bodyText:
              'Overall grade: ${r.overallGrade}. GC content: ${r.gcContent.toStringAsFixed(1)}%. '
              'N content: ${r.nPercent.toStringAsFixed(2)}%.'
              '${r.meanQuality >= 0 ? ' Mean Phred quality: ${r.meanQuality.toStringAsFixed(1)} (Q30: ${r.q30Percent.toStringAsFixed(1)}%).' : ''}',
          table: [
            ['Metric', 'Value'],
            ['Length', '${r.length} bp'],
            ['GC%', r.gcContent.toStringAsFixed(1)],
            ['N%', r.nPercent.toStringAsFixed(2)],
            if (r.meanQuality >= 0) ['Mean Q', r.meanQuality.toStringAsFixed(1)],
            ['Grade', r.overallGrade],
          ],
        ),
      ];
    },
  ),
  _WorkflowTask(
    id: 'species',
    label: 'Species / Domain ID',
    description: 'Lineage & domain-of-life identification',
    icon: Icons.pets_rounded,
    run: (seq) {
      final matches = IdentificationEngine.identify(seq.sequence, topN: 5);
      final domain = IdentificationEngine.classifyDomain(seq.sequence);
      final rows = <List<String>>[
        ['Reference', 'Marker', 'Similarity %', 'Confidence'],
      ];
      for (final m in matches) {
        rows.add([
          m.reference.scientificName,
          m.reference.markerGene,
          m.similarityPercent.toStringAsFixed(1),
          IdentificationEngine.confidenceLabel(m.similarityPercent),
        ]);
      }
      return [
        ReportSection(
          title: 'Species / Domain Identification',
          bodyText:
              'Predicted domain: ${domain.domainLabel} (${domain.confidence.toStringAsFixed(1)}% confidence).\n'
              '${domain.basis}',
        ),
        if (rows.length > 1) ReportSection(title: 'Top k-mer matches', table: rows),
      ];
    },
  ),
  _WorkflowTask(
    id: 'primer',
    label: 'Primer Design',
    description: 'Best-scoring PCR forward/reverse primer pairs',
    icon: Icons.biotech_rounded,
    run: (seq) {
      final pairs = PrimerEngine.designPrimerPairs(seq.sequence, maxPairs: 5);
      if (pairs.isEmpty) {
        return [
          ReportSection(
            title: 'Primer Design',
            bodyText:
                'No suitable primer pairs were found for this sequence (too short, or none '
                'met the GC/Tm/dimer-risk criteria).',
          ),
        ];
      }
      final rows = <List<String>>[
        ['Forward (5\'→3\')', 'Reverse (5\'→3\')', 'Product size', 'Tm diff (°C)', 'Pair score'],
      ];
      for (final p in pairs) {
        rows.add([
          p.forward.sequence,
          p.reverse.sequence,
          '${p.productSize} bp',
          p.tmDifference.toStringAsFixed(1),
          p.pairScore.toStringAsFixed(1),
        ]);
      }
      return [ReportSection(title: 'Primer Design — top candidate pairs', table: rows)];
    },
  ),
  _WorkflowTask(
    id: 'annotation',
    label: 'Annotation (ORF finder)',
    description: '6-frame ORF scan ≥ 60 nt',
    icon: Icons.label_important_rounded,
    run: (seq) {
      final orfs = AnnotationEngine.findOrfs(seq.sequence, minLengthNt: 60);
      if (orfs.isEmpty) {
        return [
          ReportSection(
            title: 'Annotation (ORF Finder)',
            bodyText: 'No open reading frames of at least 60 nt were found in any of the 6 frames.',
          ),
        ];
      }
      final rows = <List<String>>[
        ['Start', 'End', 'Frame', 'Strand', 'Length (nt)', 'Protein preview'],
      ];
      for (final o in orfs.take(10)) {
        rows.add([
          '${o.start}',
          '${o.end}',
          '${o.frame}',
          o.forwardStrand ? '+' : '-',
          '${o.length}',
          o.proteinPreview,
        ]);
      }
      return [ReportSection(title: 'Annotation — top ORFs found', table: rows)];
    },
  ),
  _WorkflowTask(
    id: 'rna',
    label: 'RNA Analysis',
    description: 'RNA class ID & secondary-structure folding',
    icon: Icons.change_history_rounded,
    run: (seq) {
      final cls = RnaEngine.classify(seq.sequence);
      final fold = RnaEngine.predictSecondaryStructure(seq.sequence);
      return [
        ReportSection(
          title: 'RNA Analysis — Classification',
          bodyText:
              'Predicted class: ${cls.guess.name} (${cls.confidence.toStringAsFixed(0)}% confidence).\n'
              '${cls.reasons.join(' ')}',
        ),
        ReportSection(
          title: 'RNA Secondary Structure (Nussinov)',
          bodyText:
              'Predicted ${fold.pairCount} base pair(s) on the first ${fold.sequence.length} nt.\n'
              'Dot-bracket notation: ${fold.dotBracket}',
        ),
      ];
    },
  ),
  _WorkflowTask(
    id: 'proteomics',
    label: 'Proteomics',
    description: 'MW, pI, GRAVY & composition (auto-translated)',
    icon: Icons.science_rounded,
    run: (seq) {
      final r = ProteomicsEngine.analyze(_translatedProtein(seq));
      return [
        ReportSection(
          title: 'Proteomics',
          bodyText:
              'Translated/cleaned protein length: ${r.proteinSequence.length} aa.\n'
              'Molecular weight: ${r.molecularWeightDa.toStringAsFixed(1)} Da. '
              'Theoretical pI: ${r.isoelectricPoint.toStringAsFixed(2)}. '
              'GRAVY (hydrophobicity): ${r.gravyScore.toStringAsFixed(2)}. '
              'Aliphatic index: ${r.aliphaticIndex.toStringAsFixed(1)}.',
        ),
      ];
    },
  ),
  _WorkflowTask(
    id: 'targets',
    label: 'Therapeutic & Vaccine Targets',
    description: 'Transmembrane & epitope triage (auto-translated)',
    icon: Icons.vaccines_rounded,
    run: (seq) {
      final r = TargetAnalysisEngine.analyze(_translatedProtein(seq));
      final rows = <List<String>>[
        ['Peptide', 'Start', 'End', 'Antigenicity', 'Surface exposed'],
      ];
      for (final e in r.vaccineTargetCandidates.take(8)) {
        rows.add([
          e.peptide,
          '${e.start}',
          '${e.end}',
          e.antigenicityScore.toStringAsFixed(1),
          e.surfaceExposed ? 'Yes' : 'No',
        ]);
      }
      return [
        ReportSection(
          title: 'Therapeutic & Vaccine Targets',
          bodyText:
              '${r.transmembraneRegions.length} transmembrane region(s) detected. '
              '${r.vaccineTargetCandidates.length} candidate vaccine target(s) ranked.\n'
              '${r.disclaimer}',
        ),
        if (rows.length > 1) ReportSection(title: 'Top vaccine target candidates', table: rows),
      ];
    },
  ),
  _WorkflowTask(
    id: 'statistics',
    label: 'Statistics',
    description: 'Descriptive stats & diversity index',
    icon: Icons.bar_chart_rounded,
    run: (seq) {
      final r = StatisticsEngine.analyzeCollection([seq]);
      return [
        ReportSection(
          title: 'Statistics',
          bodyText:
              'Length: ${r.lengthStats.mean.toStringAsFixed(1)} bp. '
              'GC%: ${r.gcStats.mean.toStringAsFixed(1)}%.\n'
              'Shannon diversity index (H\'): ${r.shannonDiversityIndex.toStringAsFixed(3)}. '
              'Simpson diversity index: ${r.simpsonDiversityIndex.toStringAsFixed(3)}.',
        ),
      ];
    },
  ),
];

/// "Smart Workflow": pick one sequence, check the analyses you want, and
/// Genome Analyzer runs them one after another, then compiles every result
/// into a single [WorkflowResultRecord] tied to your account — visible any
/// time from "My Results".
class SmartWorkflowScreen extends StatefulWidget {
  const SmartWorkflowScreen({super.key});

  @override
  State<SmartWorkflowScreen> createState() => _SmartWorkflowScreenState();
}

class _SmartWorkflowScreenState extends State<SmartWorkflowScreen> {
  String? _selectedId;
  final Set<String> _selectedTaskIds = {};
  bool _running = false;
  int _stepIndex = 0;
  String _currentStepLabel = '';
  WorkflowResultRecord? _lastResult;

  void _toggleTask(String id) {
    setState(() {
      if (_selectedTaskIds.contains(id)) {
        _selectedTaskIds.remove(id);
      } else {
        _selectedTaskIds.add(id);
      }
    });
  }

  Future<void> _runWorkflow() async {
    final seq = SequenceUtil.byId(context, _selectedId);
    if (seq == null || _selectedTaskIds.isEmpty) return;
    final auth = context.read<AuthService>();
    final tasks = _availableTasks.where((t) => _selectedTaskIds.contains(t.id)).toList();

    setState(() {
      _running = true;
      _stepIndex = 0;
      _lastResult = null;
    });

    final allSections = <ReportSection>[];
    for (final task in tasks) {
      setState(() {
        _stepIndex++;
        _currentStepLabel = task.label;
      });
      // Small delay between steps so the sequential progress is visible and
      // the UI thread stays responsive, as requested ("les lancer les uns à
      // la suite des autres").
      await Future.delayed(const Duration(milliseconds: 250));
      try {
        allSections.addAll(task.run(seq));
      } catch (e) {
        allSections.add(
          ReportSection(title: task.label, bodyText: 'This task could not be completed: $e'),
        );
      }
    }

    final reportData = ReportData(
      title: 'Smart Workflow — ${seq.name}',
      subtitle: '${tasks.length} analysis task(s) run sequentially on "${seq.name}"',
      sections: allSections,
    );

    final record = WorkflowResultRecord(
      ownerId: auth.currentUser?.id ?? '',
      ownerEmail: auth.currentUser?.email ?? '',
      sequenceName: seq.name,
      taskLabels: tasks.map((t) => t.label).toList(),
      reportData: reportData,
    );

    await StorageService.saveWorkflowResult(record);
    await auth.logActivity(
      module: 'Smart Workflow',
      action: 'Workflow run (${tasks.map((t) => t.label).join(", ")}) on "${seq.name}"',
    );

    if (!mounted) return;
    setState(() {
      _running = false;
      _lastResult = record;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canRun = _selectedId != null && _selectedTaskIds.isNotEmpty && !_running;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Workflow'),
        actions: [
          IconButton(
            tooltip: 'My Results',
            icon: const Icon(Icons.folder_special_rounded),
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MyResultsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFE040FB)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pick a sequence, check what you want to run, and Genome Analyzer will '
                    'launch every selected analysis one after another, then save the combined '
                    'result to your account — visible any time under "My Results".',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SequenceSelector(
            selectedIds: _selectedId == null ? [] : [_selectedId!],
            multiple: false,
            onChanged: (v) => setState(() => _selectedId = v.isEmpty ? null : v.first),
            label: 'Select the sequence to analyze',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'What would you like to do?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
              TextButton.icon(
                onPressed: _running
                    ? null
                    : () => setState(() {
                        if (_selectedTaskIds.length == _availableTasks.length) {
                          _selectedTaskIds.clear();
                        } else {
                          _selectedTaskIds
                            ..clear()
                            ..addAll(_availableTasks.map((t) => t.id));
                        }
                      }),
                icon: Icon(
                  _selectedTaskIds.length == _availableTasks.length
                      ? Icons.deselect_rounded
                      : Icons.select_all_rounded,
                  size: 16,
                ),
                label: Text(
                  _selectedTaskIds.length == _availableTasks.length
                      ? 'Deselect all'
                      : 'Select all',
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._availableTasks.map(
            (t) => _TaskCheckTile(
              task: t,
              checked: _selectedTaskIds.contains(t.id),
              onChanged: _running ? null : () => _toggleTask(t.id),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canRun ? _runWorkflow : null,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                _running
                    ? 'Running step $_stepIndex/${_selectedTaskIds.length}: $_currentStepLabel...'
                    : 'Run selected analyses',
              ),
            ),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 24),
            _ResultPreview(record: _lastResult!),
          ],
        ],
      ),
    );
  }
}

class _TaskCheckTile extends StatelessWidget {
  final _WorkflowTask task;
  final bool checked;
  final VoidCallback? onChanged;
  const _TaskCheckTile({required this.task, required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onChanged,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: checked ? const Color(0xFFF3E5F5) : Colors.white,
            border: Border.all(color: checked ? const Color(0xFF6A1B9A) : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                checked ? Icons.check_box : Icons.check_box_outline_blank,
                color: checked ? const Color(0xFF6A1B9A) : Colors.grey,
              ),
              const SizedBox(width: 10),
              Icon(task.icon, size: 18, color: const Color(0xFF6A1B9A)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    Text(
                      task.description,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPreview extends StatelessWidget {
  final WorkflowResultRecord record;
  const _ResultPreview({required this.record});

  @override
  Widget build(BuildContext context) {
    final data = record.reportData;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt_rounded, color: AppColors.success),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Workflow complete — saved to My Results',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
                ExportMenuButton(reportBuilder: () => data, moduleType: 'Smart Workflow'),
              ],
            ),
            const SizedBox(height: 10),
            Text(data.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const Divider(height: 24),
            ...data.sections.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    if (s.bodyText != null) ...[
                      const SizedBox(height: 4),
                      Text(s.bodyText!, style: const TextStyle(fontSize: 12, height: 1.4)),
                    ],
                    if (s.table != null) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 32,
                          dataRowMinHeight: 28,
                          dataRowMaxHeight: 44,
                          columns: s.table!.first
                              .map(
                                (h) => DataColumn(
                                  label: Text(h, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              )
                              .toList(),
                          rows: s.table!
                              .skip(1)
                              .map(
                                (row) => DataRow(
                                  cells: row
                                      .map((c) => DataCell(Text(c, style: const TextStyle(fontSize: 11))))
                                      .toList(),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
