import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/online_tool.dart';
import '../services/auth_service.dart';
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
  Future<void> _launch(String url, {String? module, String? action}) async {
    final uri = Uri.parse(url);
    final authService = context.read<AuthService>();
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (module != null && action != null) {
        await authService.logActivity(module: module, action: action);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    }
  }

  Future<void> _openTool(OnlineTool tool) =>
      _launch(tool.url, module: 'Online Tools Hub', action: 'Open ${tool.name}');

  Future<void> _connectTool(OnlineTool tool) =>
      _launch(tool.loginUrl ?? tool.url, module: 'Online Tools Hub', action: 'Connect ${tool.name}');

  Future<void> _applyQuery(OnlineTool tool, String query) {
    if (query.trim().isEmpty) return _openTool(tool);
    return _launch(
      tool.buildQueryUrl(query),
      module: 'Online Tools Hub',
      action: 'Query ${tool.name}: $query',
    );
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
                      ? 'Vous êtes en ligne. Utilisez "Appliquer" pour lancer directement une requête sur le '
                            'site du fournisseur, ou "Se connecter" pour accéder à votre propre compte.'
                      : 'Vous semblez hors ligne. Reconnectez-vous pour utiliser les requêtes en direct ; '
                            'les liens resteront disponibles dès que la connexion sera rétablie.',
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
              tools: OnlineToolsCatalog.tools.where((t) => t.category == cat).toList(),
              onOpen: _openTool,
              onConnect: _connectTool,
              onApplyQuery: _applyQuery,
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
  final void Function(OnlineTool) onConnect;
  final void Function(OnlineTool, String) onApplyQuery;
  const _CategorySection({
    required this.category,
    required this.tools,
    required this.onOpen,
    required this.onConnect,
    required this.onApplyQuery,
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
            (tool) => _ToolCard(
              tool: tool,
              onOpen: onOpen,
              onConnect: onConnect,
              onApplyQuery: onApplyQuery,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single tool card. When the tool supports a direct query deep-link, an
/// inline text field + "Appliquer" button lets the user jump straight to
/// the provider's results page with their query pre-filled — this is the
/// realistic implementation of "accéder directement à la requête et
/// appliquer" (a true embedded/programmatic query isn't possible for most
/// of these providers without their own authenticated backend, but a
/// pre-filled deep-link avoids retyping the search on their site).
class _ToolCard extends StatefulWidget {
  final OnlineTool tool;
  final void Function(OnlineTool) onOpen;
  final void Function(OnlineTool) onConnect;
  final void Function(OnlineTool, String) onApplyQuery;
  const _ToolCard({
    required this.tool,
    required this.onOpen,
    required this.onConnect,
    required this.onApplyQuery,
  });

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _expanded = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            title: Text(
              tool.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            subtitle: Text(tool.description, style: const TextStyle(fontSize: 11.5)),
            trailing: Wrap(
              spacing: 4,
              children: [
                if (tool.supportsDirectQuery)
                  IconButton(
                    tooltip: _expanded ? 'Masquer la requête' : 'Requête directe',
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.search,
                      color: AppColors.primaryBlue,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                if (tool.supportsAccount)
                  IconButton(
                    tooltip: 'Se connecter à votre compte',
                    icon: const Icon(Icons.login_rounded, color: AppColors.success),
                    onPressed: () => widget.onConnect(tool),
                  ),
                IconButton(
                  tooltip: 'Ouvrir',
                  icon: const Icon(Icons.open_in_new, color: AppColors.textMuted),
                  onPressed: () => widget.onOpen(tool),
                ),
              ],
            ),
          ),
          if (_expanded && tool.supportsDirectQuery)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: tool.queryHint ?? 'Requête',
                      ),
                      onSubmitted: (q) => widget.onApplyQuery(tool, q),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => widget.onApplyQuery(tool, _ctrl.text),
                    child: const Text('Appliquer'),
                  ),
                ],
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
        final r = await OnlineApiService.uniprotSearch(_ctrl.text.trim(), size: 3);
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
      } else if (mounted) {
        await context.read<AuthService>().logActivity(
          module: 'Online Tools Hub',
          action: 'Live query $_source: ${_ctrl.text.trim()}',
        );
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
