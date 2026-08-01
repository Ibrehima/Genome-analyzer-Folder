import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../engines/annotation_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';

class AnnotationScreen extends StatefulWidget {
  const AnnotationScreen({super.key});

  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen> {
  String? _selectedId;
  List<OrfResult> _orfs = [];
  bool _running = false;

  void _runOrfFinder(String sequence) {
    setState(() => _running = true);
    final orfs = AnnotationEngine.findOrfs(sequence);
    setState(() {
      _orfs = orfs;
      _running = false;
    });
  }

  Future<void> _addAnnotationDialog({OrfResult? fromOrf}) async {
    if (_selectedId == null) return;
    final labelCtrl = TextEditingController(
      text: fromOrf != null ? 'ORF (${fromOrf.length} nt)' : '',
    );
    final startCtrl = TextEditingController(
      text: fromOrf != null ? '${fromOrf.start + 1}' : '',
    );
    final endCtrl = TextEditingController(
      text: fromOrf != null ? '${fromOrf.end}' : '',
    );
    final noteCtrl = TextEditingController(
      text: fromOrf != null ? fromOrf.proteinPreview : '',
    );
    String featureType = fromOrf != null ? 'ORF' : 'custom';
    bool forward = fromOrf?.forwardStrand ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Annotation',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(labelText: 'Label'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Start (1-based)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: endCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'End'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: featureType,
                          decoration: const InputDecoration(
                            labelText: 'Feature type',
                          ),
                          items:
                              const [
                                    'gene',
                                    'CDS',
                                    'ORF',
                                    'exon',
                                    'motif',
                                    'custom',
                                  ]
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) =>
                              setDialogState(() => featureType = v ?? 'custom'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<bool>(
                          initialValue: forward,
                          decoration: const InputDecoration(
                            labelText: 'Strand',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: true,
                              child: Text('+ (forward)'),
                            ),
                            DropdownMenuItem(
                              value: false,
                              child: Text('- (reverse)'),
                            ),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => forward = v ?? true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final start = (int.tryParse(startCtrl.text) ?? 1) - 1;
                          final end = int.tryParse(endCtrl.text) ?? start + 1;
                          if (labelCtrl.text.trim().isEmpty || end <= start) {
                            return;
                          }
                          await context.read<AppState>().addAnnotation(
                            SequenceAnnotation(
                              sequenceId: _selectedId!,
                              start: start,
                              end: end,
                              label: labelCtrl.text.trim(),
                              featureType: featureType,
                              forwardStrand: forward,
                              note: noteCtrl.text.trim(),
                            ),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Save Annotation'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadGff3(
    String seqId,
    List<SequenceAnnotation> annots,
  ) async {
    final gff = AnnotationEngine.toGff3(seqId, annots);
    await FileSaver.instance.saveFile(
      name: 'annotations_${seqId.substring(0, 6)}',
      bytes: Uint8List.fromList(utf8.encode(gff)),
      ext: 'gff3',
      mimeType: MimeType.text,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GFF3 file downloaded.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  ReportData _buildReport(List<SequenceAnnotation> annots, String seqName) {
    return ReportData(
      title: 'Sequence Annotation Report',
      subtitle: seqName,
      sections: [
        ReportSection(
          title: 'ORFs Found (6-frame scan)',
          table: [
            ['Start', 'End', 'Frame', 'Strand', 'Length (nt)'],
            ..._orfs
                .take(50)
                .map(
                  (o) => [
                    '${o.start + 1}',
                    '${o.end}',
                    '${o.frame}',
                    o.forwardStrand ? '+' : '-',
                    '${o.length}',
                  ],
                ),
          ],
        ),
        ReportSection(
          title: 'Saved Annotations',
          table: [
            ['Label', 'Type', 'Start', 'End', 'Strand', 'Note'],
            ...annots.map(
              (a) => [
                a.label,
                a.featureType,
                '${a.start + 1}',
                '${a.end}',
                a.forwardStrand ? '+' : '-',
                a.note,
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selectedSeq = _selectedId != null
        ? appState.getSequenceById(_selectedId!)
        : null;
    final annots = _selectedId != null
        ? appState.annotationsFor(_selectedId!)
        : <SequenceAnnotation>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sequence Annotation'),
        actions: [
          if (selectedSeq != null && annots.isNotEmpty)
            IconButton(
              tooltip: 'Download GFF3',
              icon: const Icon(Icons.download),
              onPressed: () => _downloadGff3(selectedSeq.id, annots),
            ),
          if (selectedSeq != null)
            ExportMenuButton(
              reportBuilder: () => _buildReport(annots, selectedSeq.name),
              moduleType: 'Annotation',
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: selectedSeq == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addAnnotationDialog(),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add Annotation'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          SequenceSelector(
            selectedIds: _selectedId != null ? [_selectedId!] : [],
            multiple: false,
            onChanged: (v) => setState(() {
              _selectedId = v.isNotEmpty ? v.first : null;
              _orfs = [];
            }),
            label: 'Select a DNA or RNA sequence',
          ),
          const SizedBox(height: 16),
          if (selectedSeq != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _running
                    ? null
                    : () => _runOrfFinder(selectedSeq.sequence),
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _running ? 'Scanning...' : 'Find ORFs (6-frame scan)',
                ),
              ),
            ),
          const SizedBox(height: 18),
          if (_orfs.isNotEmpty) ...[
            Text(
              '${_orfs.length} ORF(s) found (≥100 nt)',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ..._orfs
                .take(30)
                .map(
                  (o) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.gradAnnotation.first
                            .withValues(alpha: 0.15),
                        child: Text(
                          'F${o.frame}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        '${o.start + 1}-${o.end} (${o.length} nt) · ${o.forwardStrand ? "+" : "-"} strand',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        o.proteinPreview,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                        tooltip: 'Save as annotation',
                        onPressed: () => _addAnnotationDialog(fromOrf: o),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 20),
          ],
          if (annots.isNotEmpty) ...[
            Text(
              'Saved Annotations (${annots.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...annots.map(
              (a) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.label_important_outline,
                    color: AppColors.primaryBlue,
                  ),
                  title: Text(
                    a.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${a.featureType} · ${a.start + 1}-${a.end} · ${a.forwardStrand ? "+" : "-"}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    onPressed: () =>
                        context.read<AppState>().removeAnnotation(a.id),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
