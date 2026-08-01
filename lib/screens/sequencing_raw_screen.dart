import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../models/bio_sequence.dart';
import '../engines/sequencing_pipeline_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/export_menu_button.dart';

/// Raw sequencer-output ingestion module: recognizes Illumina, Oxford
/// Nanopore, PacBio and Sanger file signatures and runs a platform-specific
/// pipeline (demultiplexing, adapter/quality trimming, ZMW consensus,
/// Mott trace trimming) up to a clean FASTA/FASTQ result.
class SequencingRawScreen extends StatefulWidget {
  const SequencingRawScreen({super.key});

  @override
  State<SequencingRawScreen> createState() => _SequencingRawScreenState();
}

class _SequencingRawScreenState extends State<SequencingRawScreen> {
  String? _fileName;
  Uint8List? _fileBytes;
  String? _textContent;
  SequencingPlatform? _detected;
  SequencingPlatform? _override;
  bool _busy = false;
  SequencingPipelineResult? _result;
  final _barcodeCtrl = TextEditingController(
    text: 'SampleA,ACGTAC\nSampleB,TGCATG',
  );
  bool _useBarcodes = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    String? text;
    final looksBinary =
        file.name.toLowerCase().endsWith('.ab1') ||
        file.name.toLowerCase().endsWith('.scf');
    if (!looksBinary) {
      try {
        text = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        text = null;
      }
    }
    final detected = SequencingPipelineEngine.detectPlatform(
      fileName: file.name,
      bytes: bytes,
      textPreview: text,
    );
    setState(() {
      _fileName = file.name;
      _fileBytes = bytes;
      _textContent = text;
      _detected = detected;
      _override = null;
      _result = null;
    });
  }

  List<DemuxSample> _parseBarcodes() {
    final lines = _barcodeCtrl.text
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty);
    final list = <DemuxSample>[];
    for (final line in lines) {
      final parts = line.split(',');
      if (parts.length >= 2) {
        list.add(
          DemuxSample(
            name: parts[0].trim(),
            barcode: parts[1].trim().toUpperCase(),
          ),
        );
      }
    }
    return list;
  }

  Future<void> _run() async {
    if (_fileBytes == null || _fileName == null) return;
    final platform = _override ?? _detected ?? SequencingPlatform.unknown;
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      SequencingPipelineResult result;
      switch (platform) {
        case SequencingPlatform.illumina:
          result = SequencingPipelineEngine.processIllumina(
            _textContent ?? '',
            barcodes: _useBarcodes ? _parseBarcodes() : const [],
          );
          break;
        case SequencingPlatform.nanopore:
          result = SequencingPipelineEngine.processNanopore(_textContent ?? '');
          break;
        case SequencingPlatform.pacbio:
          result = SequencingPipelineEngine.processPacBio(_textContent ?? '');
          break;
        case SequencingPlatform.sanger:
          result = SequencingPipelineEngine.processSanger(
            _fileBytes!,
            fileName: _fileName!,
          );
          break;
        case SequencingPlatform.unknown:
          result = SequencingPipelineResult(
            platform: SequencingPlatform.unknown,
            stepsLog: [
              'Could not automatically recognize the platform from this file. '
                  'Please manually select a platform above and retry.',
            ],
            outputSequences: [],
            warnings: ['Unrecognized format.'],
          );
          break;
      }
      setState(() => _result = result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAllToLibrary() async {
    if (_result == null || _result!.outputSequences.isEmpty) return;
    await context.read<AppState>().addSequences(_result!.outputSequences);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${_result!.outputSequences.length} processed sequence(s) to the library.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  ReportData _buildReport() {
    final r = _result;
    if (r == null) return ReportData(title: 'Sequencing Pipeline Report');
    return ReportData(
      title: 'Raw Sequencing Data Processing Report',
      subtitle: '${r.platform.label} · ${_fileName ?? ''}',
      sections: [
        ReportSection(
          title: 'Summary',
          table: [
            ['Metric', 'Value'],
            ['Platform', r.platform.label],
            ['Input reads', '${r.inputReadCount}'],
            ['Output reads', '${r.outputSequences.length}'],
            ['Warnings', '${r.warnings.length}'],
          ],
        ),
        ReportSection(title: 'Pipeline Steps', bullets: r.stepsLog),
        if (r.warnings.isNotEmpty)
          ReportSection(title: 'Warnings', bullets: r.warnings),
        ReportSection(
          title: 'Output Sequences',
          table: [
            ['Name', 'Length (bp)', 'Type', 'Source'],
            ...r.outputSequences.map(
              (s) => [s.name, '${s.length}', s.type.label, s.source],
            ),
          ],
        ),
      ],
    );
  }

  String _platformIcon(SequencingPlatform p) {
    switch (p) {
      case SequencingPlatform.illumina:
        return '🧬';
      case SequencingPlatform.nanopore:
        return '🕳️';
      case SequencingPlatform.pacbio:
        return '⭕';
      case SequencingPlatform.sanger:
        return '📈';
      case SequencingPlatform.unknown:
        return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raw Sequencing Data'),
        actions: [
          if (_result != null && _result!.outputSequences.isNotEmpty)
            ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: 'Sequencing Pipeline',
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
              color: AppColors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.teal, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Upload raw reads from Illumina, Oxford Nanopore, PacBio '
                    '(FASTQ/FASTA) or Sanger (.ab1 trace) sequencers. The app '
                    'recognizes the platform signature and runs demultiplexing, '
                    'adapter/quality trimming or ZMW consensus to produce a '
                    'clean FASTA/FASTQ. Note: base-calling itself is already '
                    'performed by the sequencer\'s own software — this app '
                    'processes that basecalled output, it does not decode raw '
                    'instrument signals (squiggles / fluorescence traces).',
                    style: TextStyle(fontSize: 12, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file),
            label: Text(
              _fileName == null ? 'Select raw sequencing file' : _fileName!,
            ),
          ),
          if (_detected != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '${_platformIcon(_detected!)} Detected platform: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Expanded(
                  child: Text(
                    _detected!.label,
                    style: const TextStyle(color: AppColors.primaryBlue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Override platform: ',
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(width: 6),
                DropdownButton<SequencingPlatform?>(
                  value: _override,
                  hint: const Text('Auto'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Auto (use detected)'),
                    ),
                    ...SequencingPlatform.values.map(
                      (p) => DropdownMenuItem(value: p, child: Text(p.label)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _override = v),
                ),
              ],
            ),
          ],
          if ((_override ?? _detected) == SequencingPlatform.illumina) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _useBarcodes,
              onChanged: (v) => setState(() => _useBarcodes = v),
              title: const Text(
                'Demultiplex using sample barcode sheet',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'One "SampleName,BARCODE" per line — in-line 5\' barcode match (Hamming ≤ 1).',
                style: TextStyle(fontSize: 11.5),
              ),
            ),
            if (_useBarcodes)
              TextField(
                controller: _barcodeCtrl,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: 'Sample sheet (name,barcode)',
                ),
              ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fileBytes == null || _busy ? null : _run,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_circle_outline),
              label: Text(_busy ? 'Processing...' : 'Run Pipeline'),
            ),
          ),
          const SizedBox(height: 20),
          if (_result != null)
            _PipelineResultView(
              result: _result!,
              onAddToLibrary: _addAllToLibrary,
            ),
        ],
      ),
    );
  }
}

class _PipelineResultView extends StatelessWidget {
  final SequencingPipelineResult result;
  final VoidCallback onAddToLibrary;
  const _PipelineResultView({
    required this.result,
    required this.onAddToLibrary,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pipeline Log — ${result.platform.label}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text('${result.outputSequences.length} reads out'),
                      backgroundColor: AppColors.success.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...result.stepsLog.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 15,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (result.warnings.isNotEmpty) ...[
                  const Divider(),
                  ...result.warnings.map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 15,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              w,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (result.outputSequences.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Output Reads',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              TextButton.icon(
                onPressed: onAddToLibrary,
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Add all to Library'),
              ),
            ],
          ),
          ...result.outputSequences
              .take(50)
              .map(
                (s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.dns_rounded,
                      color: AppColors.primaryBlue,
                    ),
                    title: Text(
                      s.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${s.type.label} · ${s.length} bp${s.hasQuality ? " · has quality" : ""}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
          if (result.outputSequences.length > 50)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '... and ${result.outputSequences.length - 50} more reads (showing first 50).',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
