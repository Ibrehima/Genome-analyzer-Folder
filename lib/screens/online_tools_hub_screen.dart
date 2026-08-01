import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/online_tool.dart';
import '../services/connectivity_service.dart';
import '../services/online_api_service.dart';
import '../utils/app_theme.dart';
import '../widgets/connectivity_badge.dart';

class OnlineToolsHubScreen extends StatefulWidget {
  const OnlineToolsHubScreen({super.key});

  @override
  State<OnlineToolsHubScreen> createState() => _OnlineToolsHubScreenState();
}

class _OnlineToolsHubScreenState extends State<OnlineToolsHubScreen> {
  Future<void> _openTool(OnlineTool tool) async {
    final uri = Uri.parse(tool.url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open ${tool.url}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = OnlineToolsCatalog.categories;
    final conn = context.watch<ConnectivityService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Tools Hub'),
        actions: const [ConnectivityBadge(), SizedBox(width: 12)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.gradOnline),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.public, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Connect to the wider bioinformatics ecosystem',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  conn.isOnline
                      ? 'You are online. Live queries below use real public APIs. Tap "Open" on any tool to sign into your own account on their website.'
                      : 'You appear offline. Reconnect to use live queries; tool links will still open once connectivity is available.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Live Queries (Real Public APIs)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          const SizedBox(height: 10),
          const _LiveQueryPanel(),
          const SizedBox(height: 24),
          ...categories.map(
            (cat) => _CategorySection(
              category: cat,
              tools: OnlineToolsCatalog.tools
                  .where((t) => t.category == cat)
                  .toList(),
              onOpen: _openTool,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<OnlineTool> tools;
  final void Function(OnlineTool) onOpen;
  const _CategorySection({
    required this.category,
    required this.tools,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          ...tools.map(
            (tool) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  tool.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  tool.description,
                  style: const TextStyle(fontSize: 11.5),
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (tool.supportsAccount)
                      const Tooltip(
                        message: 'Sign in to your own account on their site',
                        child: Icon(
                          Icons.person_outline,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.open_in_new,
                        color: AppColors.primaryBlue,
                      ),
                      onPressed: () => onOpen(tool),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveQueryPanel extends StatefulWidget {
  const _LiveQueryPanel();

  @override
  State<_LiveQueryPanel> createState() => _LiveQueryPanelState();
}

class _LiveQueryPanelState extends State<_LiveQueryPanel> {
  final _ctrl = TextEditingController(text: 'Homo sapiens');
  String _source = 'GBIF';
  bool _loading = false;
  String? _result;
  String? _error;

  Future<void> _query() async {
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      if (_source == 'GBIF') {
        final r = await OnlineApiService.gbifSpeciesMatch(_ctrl.text.trim());
        _result = r == null
            ? null
            : 'Scientific name: ${r['scientificName']}\nRank: ${r['rank']}\nKingdom: ${r['kingdom']}\nConfidence: ${r['confidence']}';
      } else if (_source == 'UniProt') {
        final r = await OnlineApiService.uniprotSearch(
          _ctrl.text.trim(),
          size: 3,
        );
        _result = r == null || r.isEmpty
            ? null
            : r
                  .map(
                    (e) =>
                        '${e['primaryAccession']} — ${e['proteinDescription']?['recommendedName']?['fullName']?['value'] ?? ''} (${e['organism']?['scientificName'] ?? ''})',
                  )
                  .join('\n');
      } else {
        final r = await OnlineApiService.ensemblLookupSymbol(_ctrl.text.trim());
        _result = r == null
            ? null
            : 'Gene: ${r['display_name']}\nDescription: ${r['description']}\nLocation: ${r['seq_region_name']}:${r['start']}-${r['end']}';
      }
      if (_result == null) {
        _error =
            'No result (or blocked by browser CORS policy — this works reliably in the Android app). Try "Open" links below instead.';
      }
    } catch (e) {
      _error = 'Query failed: $e';
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: ['GBIF', 'UniProt', 'Ensembl']
                  .map(
                    (s) => ChoiceChip(
                      label: Text(s),
                      selected: _source == s,
                      onSelected: (_) => setState(() => _source = s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                labelText: _source == 'Ensembl'
                    ? 'Gene symbol (e.g. BRCA1)'
                    : 'Species / protein / query',
                suffixIcon: IconButton(
                  icon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  onPressed: _loading ? null : _query,
                ),
              ),
              onSubmitted: (_) => _query(),
            ),
            if (_result != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_result!, style: const TextStyle(fontSize: 12.5)),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
