import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/bio_sequence.dart';
import '../engines/sequence_engine.dart';
import '../data/reference_database.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/colored_sequence_view.dart';

enum _SortMode { dateDesc, dateAsc, nameAsc, lengthDesc, lengthAsc }

class SequenceLibraryScreen extends StatefulWidget {
  final bool embedded;
  const SequenceLibraryScreen({super.key, this.embedded = false});

  @override
  State<SequenceLibraryScreen> createState() => _SequenceLibraryScreenState();
}

class _SequenceLibraryScreenState extends State<SequenceLibraryScreen> {
  bool _busy = false;
  String _search = '';
  SequenceType? _typeFilter;
  _SortMode _sortMode = _SortMode.dateDesc;

  Future<void> _pickFile() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['fasta', 'fa', 'fastq', 'fq', 'txt'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          final content = utf8.decode(bytes, allowMalformed: true);
          final seqs = SequenceEngine.parseAuto(
            content,
            source: 'upload:${file.name}',
          );
          if (seqs.isEmpty) {
            _showSnack('No valid sequences found in file.', error: true);
          } else if (mounted) {
            await context.read<AppState>().addSequences(seqs);
            if (mounted) {
              _showSnack(
                'Imported ${seqs.length} sequence(s) from ${file.name}.',
              );
            }
          }
        }
      }
    } catch (e) {
      _showSnack('Import failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  Future<void> _showPasteDialog() async {
    final nameCtrl = TextEditingController();
    final seqCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Sequence Manually',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Sequence name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: seqCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Paste sequence (FASTA content or raw letters)',
                    alignLabelWithHint: true,
                  ),
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
                        final raw = seqCtrl.text.trim();
                        if (raw.isEmpty) return;
                        List<BioSequence> parsed;
                        if (raw.startsWith('>')) {
                          parsed = SequenceEngine.parseFasta(
                            raw,
                            source: 'manual',
                          );
                        } else {
                          final clean = SequenceEngine.sanitize(raw);
                          parsed = [
                            BioSequence(
                              name: nameCtrl.text.trim().isEmpty
                                  ? 'sequence_${DateTime.now().millisecondsSinceEpoch}'
                                  : nameCtrl.text.trim(),
                              type: SequenceEngine.detectType(clean),
                              sequence: clean,
                              source: 'manual',
                            ),
                          ];
                        }
                        await context.read<AppState>().addSequences(parsed);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSnack('Added ${parsed.length} sequence(s).');
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadSamples() async {
    final samples = ReferenceDatabase.records
        .take(6)
        .map(
          (r) => BioSequence(
            name: r.scientificName,
            description: '${r.commonName} · ${r.markerGene}',
            type: SequenceEngine.detectType(r.sequence),
            sequence: r.sequence,
            source: 'sample',
            tags: ['sample', r.markerGene],
          ),
        );
    await context.read<AppState>().addSequences(samples.toList());
    _showSnack('Loaded ${samples.length} sample sequences.');
  }

  Future<void> _downloadFasta(BioSequence seq) async {
    final fasta = '>${seq.name} ${seq.description}\n${seq.sequence}\n';
    await FileSaver.instance.saveFile(
      name: seq.name.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_'),
      bytes: Uint8List.fromList(utf8.encode(fasta)),
      ext: 'fasta',
      mimeType: MimeType.text,
    );
    _showSnack('Downloaded ${seq.name}.fasta');
  }

  Future<void> _downloadAllFasta(List<BioSequence> seqs) async {
    final buf = StringBuffer();
    for (final s in seqs) {
      buf.writeln('>${s.labCode}|${s.name} ${s.description}');
      buf.writeln(s.sequence);
    }
    await FileSaver.instance.saveFile(
      name: 'genome_analyzer_library_export',
      bytes: Uint8List.fromList(utf8.encode(buf.toString())),
      ext: 'fasta',
      mimeType: MimeType.text,
    );
    _showSnack('Downloaded ${seqs.length} sequences as one multi-FASTA file.');
  }

  void _showDetail(BioSequence seq) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 560,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          seq.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (seq.labCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            seq.labCode,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    seq.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(label: Text(seq.type.label)),
                      Chip(label: Text('${seq.length} bp')),
                      Chip(
                        label: Text(
                          'GC ${SequenceEngine.gcContent(seq.sequence).toStringAsFixed(1)}%',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Added ${seq.dateAdded.toString().substring(0, 10)}',
                        ),
                      ),
                      if (seq.hasQuality)
                        const Chip(label: Text('FASTQ (with quality)')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const SequenceLegend(),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: ColoredSequenceView(
                        sequence: seq.sequence,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _downloadFasta(seq),
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download FASTA'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
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

  List<BioSequence> _filteredSorted(List<BioSequence> all) {
    var list = all.where((s) {
      if (_typeFilter != null && s.type != _typeFilter) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!s.name.toLowerCase().contains(q) &&
            !s.labCode.toLowerCase().contains(q) &&
            !s.description.toLowerCase().contains(q) &&
            !s.tags.any((t) => t.toLowerCase().contains(q))) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (_sortMode) {
      case _SortMode.dateDesc:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case _SortMode.dateAsc:
        list.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
      case _SortMode.nameAsc:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case _SortMode.lengthDesc:
        list.sort((a, b) => b.length.compareTo(a.length));
        break;
      case _SortMode.lengthAsc:
        list.sort((a, b) => a.length.compareTo(b.length));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sequences = context.watch<AppState>().sequences;
    final filtered = _filteredSorted(sequences);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sequence Library'),
        actions: [
          if (sequences.isNotEmpty)
            IconButton(
              tooltip: 'Download all as multi-FASTA',
              onPressed: () => _downloadAllFasta(filtered),
              icon: const Icon(Icons.folder_zip_outlined),
            ),
          IconButton(
            tooltip: 'Load sample sequences',
            onPressed: _loadSamples,
            icon: const Icon(Icons.science_outlined),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'paste',
            onPressed: _showPasteDialog,
            backgroundColor: AppColors.teal,
            icon: const Icon(Icons.edit_note),
            label: const Text('Paste'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'upload',
            onPressed: _busy ? null : _pickFile,
            backgroundColor: AppColors.primaryBlue,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_file),
            label: const Text('Upload'),
          ),
        ],
      ),
      body: sequences.isEmpty
          ? _EmptyState(onSample: _loadSamples, onUpload: _pickFile)
          : Column(
              children: [
                _FilterBar(
                  search: _search,
                  onSearchChanged: (v) => setState(() => _search = v),
                  typeFilter: _typeFilter,
                  onTypeChanged: (v) => setState(() => _typeFilter = v),
                  sortMode: _sortMode,
                  onSortChanged: (v) => setState(() => _sortMode = v),
                  count: filtered.length,
                  total: sequences.length,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 760;
                      if (!isWide) {
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _SequenceTile(
                            seq: filtered[i],
                            onTap: () => _showDetail(filtered[i]),
                            onDownload: () => _downloadFasta(filtered[i]),
                          ),
                        );
                      }
                      final cols = (constraints.maxWidth / 380).floor().clamp(
                        2,
                        4,
                      );
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 3.6,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _SequenceTile(
                          seq: filtered[i],
                          onTap: () => _showDetail(filtered[i]),
                          onDownload: () => _downloadFasta(filtered[i]),
                          card: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

Color _typeColor(SequenceType type) {
  switch (type) {
    case SequenceType.dna:
      return AppColors.primaryBlue;
    case SequenceType.rna:
      return AppColors.teal;
    case SequenceType.protein:
      return const Color(0xFF7B1FA2);
    case SequenceType.unknown:
      return Colors.grey;
  }
}

class _FilterBar extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;
  final SequenceType? typeFilter;
  final ValueChanged<SequenceType?> onTypeChanged;
  final _SortMode sortMode;
  final ValueChanged<_SortMode> onSortChanged;
  final int count;
  final int total;

  const _FilterBar({
    required this.search,
    required this.onSearchChanged,
    required this.typeFilter,
    required this.onTypeChanged,
    required this.sortMode,
    required this.onSortChanged,
    required this.count,
    required this.total,
  });

  String _sortLabel(_SortMode m) {
    switch (m) {
      case _SortMode.dateDesc:
        return 'Newest first';
      case _SortMode.dateAsc:
        return 'Oldest first';
      case _SortMode.nameAsc:
        return 'Name (A-Z)';
      case _SortMode.lengthDesc:
        return 'Length (longest)';
      case _SortMode.lengthAsc:
        return 'Length (shortest)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: AppColors.surface,
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Search name, lab code, tag...',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<SequenceType?>(
              initialValue: typeFilter,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All types')),
                ...SequenceType.values.map(
                  (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                ),
              ],
              onChanged: onTypeChanged,
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<_SortMode>(
              initialValue: sortMode,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              items: _SortMode.values
                  .map(
                    (m) =>
                        DropdownMenuItem(value: m, child: Text(_sortLabel(m))),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onSortChanged(v);
              },
            ),
          ),
          Text(
            '$count / $total sequences',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SequenceTile extends StatelessWidget {
  final BioSequence seq;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final bool card;
  const _SequenceTile({
    required this.seq,
    required this.onTap,
    required this.onDownload,
    this.card = false,
  });

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: _typeColor(seq.type).withValues(alpha: 0.15),
        child: Icon(Icons.dns_rounded, color: _typeColor(seq.type), size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              seq.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          if (seq.labCode.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                seq.labCode,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${seq.type.label} · ${seq.length} bp · ${seq.source}${seq.hasQuality ? " · FASTQ" : ""}',
        style: const TextStyle(fontSize: 11.5),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Download FASTA',
            icon: const Icon(Icons.download, size: 18),
            onPressed: onDownload,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: () => context.read<AppState>().removeSequence(seq.id),
          ),
        ],
      ),
    );
    return Card(
      margin: card ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
      child: tile,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSample;
  final VoidCallback onUpload;
  const _EmptyState({required this.onSample, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dns_rounded, size: 64, color: Color(0xFFBBDEFB)),
            const SizedBox(height: 16),
            const Text(
              'Your library is empty',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Upload a FASTA/FASTQ file, paste a sequence, or load sample data to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload File'),
                ),
                OutlinedButton.icon(
                  onPressed: onSample,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Load Samples'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
