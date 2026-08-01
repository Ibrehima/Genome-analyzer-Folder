import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../engines/sequence_engine.dart';
import '../utils/app_theme.dart';
import 'primer_design_screen.dart';
import 'alignment_screen.dart';
import 'phylo_tree_screen.dart';
import 'species_id_screen.dart';
import 'quality_control_screen.dart';
import 'statistics_screen.dart';
import 'online_tools_hub_screen.dart';
import 'sequence_library_screen.dart';
import 'reports_screen.dart';

class _ChatMessage {
  final String text;
  final bool fromUser;
  final Widget? action;
  _ChatMessage({required this.text, required this.fromUser, this.action});
}

class AssistantScreen extends StatefulWidget {
  final bool embedded;
  const AssistantScreen({super.key, this.embedded = false});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        fromUser: false,
        text:
            "Hi! I'm your Genome Analyzer assistant. Ask me to design primers, align sequences, build a "
            "phylogenetic tree, identify a species, check sequence quality, compute statistics, or export a report. "
            "Try: \"design primers\", \"align my sequences\", \"identify species\", \"check quality\".",
      ),
    );
  }

  void _scrollToEnd() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(label),
        ),
      ),
    );
  }

  void _handleQuery(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return;
    setState(() => _messages.add(_ChatMessage(text: q, fromUser: true)));
    _ctrl.clear();

    final lower = q.toLowerCase();
    final appState = context.read<AppState>();

    // Try to answer direct GC/length questions about a named sequence
    final gcMatch = RegExp(
      r'(gc content|gc%|gc)\s*(of|for)?\s*(.+)',
    ).firstMatch(lower);
    if (lower.contains('gc content') || lower.contains('gc%')) {
      final seq = _findSequenceMentioned(appState, lower);
      if (seq != null) {
        final gc = SequenceEngine.gcContent(seq.sequence);
        _reply(
          '${seq.name} has a GC content of ${gc.toStringAsFixed(2)}% over ${seq.length} bp.',
        );
        return;
      } else if (gcMatch != null) {
        _reply(
          'I could not find a sequence matching that name in your library. Open the Library tab to check exact names.',
        );
        return;
      }
    }

    if (lower.contains('length of') || lower.contains('how long')) {
      final seq = _findSequenceMentioned(appState, lower);
      if (seq != null) {
        _reply('${seq.name} is ${seq.length} bp long (${seq.type.label}).');
        return;
      }
    }

    if (_matchesAny(lower, ['primer', 'amorce'])) {
      _reply(
        'Opening the Primer Design module — select a template sequence and I\'ll scan for optimal forward/reverse primer pairs.',
        action: _actionButton(
          'Open Primer Design',
          Icons.biotech,
          () => _navigateTo(const PrimerDesignScreen()),
        ),
      );
      return;
    }
    if (_matchesAny(lower, ['align', 'alignement', 'alignment'])) {
      _reply(
        'Opening Sequence Alignment — pick 2 sequences for pairwise alignment or 3+ for multiple alignment.',
        action: _actionButton(
          'Open Alignment',
          Icons.align_horizontal_left_rounded,
          () => _navigateTo(const AlignmentScreen()),
        ),
      );
      return;
    }
    if (_matchesAny(lower, ['tree', 'phylo', 'arbre', 'phylogen'])) {
      _reply(
        'Opening Phylogenetic Tree builder — select 3+ sequences and choose UPGMA or Neighbor-Joining.',
        action: _actionButton(
          'Open Phylogenetic Tree',
          Icons.account_tree_rounded,
          () => _navigateTo(const PhyloTreeScreen()),
        ),
      );
      return;
    }
    if (_matchesAny(lower, [
      'species',
      'lineage',
      'variant',
      'identif',
      'espèce',
      'lignée',
    ])) {
      _reply(
        'Opening Species / Variant Identification — I\'ll match your sequence against the local reference database (or GBIF online).',
        action: _actionButton(
          'Open Species ID',
          Icons.pets_rounded,
          () => _navigateTo(const SpeciesIdScreen()),
        ),
      );
      return;
    }
    if (_matchesAny(lower, ['quality', 'qc', 'qualité', 'phred'])) {
      _reply(
        'Opening Quality Control — I\'ll compute GC/N content and, for FASTQ, Phred quality trends.',
        action: _actionButton(
          'Open Quality Control',
          Icons.verified_rounded,
          () => _navigateTo(const QualityControlScreen()),
        ),
      );
      return;
    }
    if (_matchesAny(lower, ['stat', 'diversity', 'diversité'])) {
      _reply(
        'Opening Statistics Lab — descriptive stats and diversity indices across your sequence collection.',
        action: _actionButton(
          'Open Statistics',
          Icons.bar_chart_rounded,
          () => _navigateTo(const StatisticsScreen()),
        ),
      );
      return;
    }
    if (_matchesAny(lower, [
      'export',
      'pdf',
      'word',
      'excel',
      'powerpoint',
      'pptx',
      'docx',
      'xlsx',
      'report',
      'rapport',
      'télécharg',
      'download',
    ])) {
      _reply(
        'Every module has an "Export" button (top-right) to download results as PDF, Word, PowerPoint or Excel. '
        'Here is your Reports & Export Center with everything you\'ve generated so far.',
        action: _actionButton(
          'Open Reports Center',
          Icons.folder_copy_rounded,
          () => _navigateTo(const ReportsScreen()),
        ),
      );
      return;
    }
    if (_matchesAny(lower, [
      'upload',
      'fasta',
      'fastq',
      'library',
      'sequence',
      'séquence',
      'paste',
    ])) {
      _reply(
        'Opening the Sequence Library — upload a FASTA/FASTQ file, paste a sequence, or load samples to get started.',
        action: _actionButton(
          'Open Library',
          Icons.dns_rounded,
          () => _navigateTo(const SequenceLibraryScreen()),
        ),
      );
      return;
    }
    if (_matchesAny(lower, [
      'blast',
      'ncbi',
      'uniprot',
      'ensembl',
      'gbif',
      'online',
      'internet',
      'itol',
      'bold',
    ])) {
      _reply(
        'Opening the Online Tools Hub — live queries to public databases plus quick links to sign into your own accounts on NCBI, EBI, UniProt and more.',
        action: _actionButton(
          'Open Online Tools Hub',
          Icons.public_rounded,
          () => _navigateTo(const OnlineToolsHubScreen()),
        ),
      );
      return;
    }
    if (_matchesAny(lower, ['help', 'aide', 'what can you do'])) {
      _reply(
        'I can help you: design primers, align sequences (pairwise/MSA), build phylogenetic trees (UPGMA/NJ), '
        'identify species/lineage/variants, run quality control, compute statistics, and export any result to PDF/Word/PowerPoint/Excel. '
        'Just tell me what you\'d like to do!',
      );
      return;
    }

    _reply(
      'I\'m not sure how to help with that yet. Try mentioning: primer, alignment, tree, species, quality, statistics, export, or online tools.',
    );
  }

  bool _matchesAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  dynamic _findSequenceMentioned(AppState appState, String lower) {
    for (final s in appState.sequences) {
      if (lower.contains(s.name.toLowerCase())) return s;
    }
    return null;
  }

  void _reply(String text, {Widget? action}) {
    setState(
      () => _messages.add(
        _ChatMessage(text: text, fromUser: false, action: action),
      ),
    );
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) =>
                  _MessageBubble(message: _messages[i]),
            ),
          ),
          _QuickChips(onTap: _handleQuery),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Ask me anything about your analysis...',
                      ),
                      onSubmitted: _handleQuery,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.gradAssistant,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () => _handleQuery(_ctrl.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChips extends StatelessWidget {
  final void Function(String) onTap;
  const _QuickChips({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      'Design primers',
      'Align my sequences',
      'Build a phylogenetic tree',
      'Identify species',
      'Check quality',
      'Compute statistics',
      'Export report',
    ];
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: suggestions
            .map(
              (s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  onPressed: () => onTap(s),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primaryBlue : Colors.white,
          border: isUser ? null : Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.textDark,
                fontSize: 13.5,
              ),
            ),
            if (message.action != null) message.action!,
          ],
        ),
      ),
    );
  }
}
