import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../engines/identification_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../services/connectivity_service.dart';
import '../services/online_api_service.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';

class SpeciesIdScreen extends StatefulWidget {
  const SpeciesIdScreen({super.key});

  @override
  State<SpeciesIdScreen> createState() => _SpeciesIdScreenState();
}

class _SpeciesIdScreenState extends State<SpeciesIdScreen> {
  List<String> _selectedIds = [];
  bool _running = false;
  List<SpeciesMatch> _matches = [];
  String? _queryName;
  Map<String, dynamic>? _onlineResult;
  bool _onlineChecking = false;
  DomainClassificationResult? _domainResult;

  Future<void> _run() async {
    if (_selectedIds.isEmpty) return;
    final seq = context.read<AppState>().getSequenceById(_selectedIds.first);
    if (seq == null) return;
    setState(() {
      _running = true;
      _queryName = seq.name;
      _onlineResult = null;
    });
    await Future.delayed(const Duration(milliseconds: 50));
    final matches = IdentificationEngine.identify(seq.sequence);
    final domain = IdentificationEngine.classifyDomain(seq.sequence);
    setState(() {
      _matches = matches;
      _domainResult = domain;
      _running = false;
    });
  }

  Future<void> _crossCheckOnline() async {
    if (_matches.isEmpty) return;
    final conn = context.read<ConnectivityService>();
    if (!conn.isOnline) {
      await conn.checkNow();
    }
    if (!conn.isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection detected.')),
        );
      }
      return;
    }
    setState(() => _onlineChecking = true);
    final best = _matches.first.reference.scientificName;
    final result = await OnlineApiService.gbifSpeciesMatch(best);
    setState(() {
      _onlineResult = result;
      _onlineChecking = false;
    });
  }

  ReportData _buildReport() {
    final rows = <List<String>>[
      [
        'Rank',
        'Scientific Name',
        'Common Name',
        'Marker Gene',
        'Similarity %',
        'Confidence',
      ],
    ];
    for (int i = 0; i < _matches.length; i++) {
      final m = _matches[i];
      rows.add([
        '${i + 1}',
        m.reference.scientificName,
        m.reference.commonName,
        m.reference.markerGene,
        m.similarityPercent.toStringAsFixed(1),
        IdentificationEngine.confidenceLabel(m.similarityPercent),
      ]);
    }
    final best = _matches.isNotEmpty ? _matches.first : null;
    return ReportData(
      title: 'Species / Lineage Identification Report',
      subtitle: 'Query: ${_queryName ?? ""}',
      sections: [
        ReportSection(
          title: 'Best Match',
          bodyText: best == null
              ? 'No match found.'
              : '${best.reference.scientificName} (${best.reference.commonName}) — ${best.similarityPercent.toStringAsFixed(1)}% k-mer similarity. '
                    'Lineage: ${best.reference.lineage.replaceAll(";", " > ")}',
        ),
        ReportSection(title: 'Top Candidate Matches', table: rows),
        if (_domainResult != null)
          ReportSection(
            title: 'Domain-of-Life / Origin Classification',
            bodyText:
                'Classification: ${_domainResult!.domainLabel} (confidence '
                '${_domainResult!.confidence.toStringAsFixed(1)}%)\n'
                '${_domainResult!.basis}',
          ),
        if (_onlineResult != null)
          ReportSection(
            title: 'Online Cross-Check (GBIF)',
            bodyText:
                'Matched taxon: ${_onlineResult!['scientificName'] ?? 'N/A'} · '
                'Rank: ${_onlineResult!['rank'] ?? 'N/A'} · Confidence: ${_onlineResult!['confidence'] ?? 'N/A'}',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Species / Variant ID'),
        actions: [
          if (_matches.isNotEmpty)
            ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: 'Species Identification',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          SequenceSelector(
            selectedIds: _selectedIds,
            onChanged: (v) => setState(() => _selectedIds = v),
            label: 'Select a query sequence',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedIds.isEmpty || _running ? null : _run,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.pets_rounded),
              label: Text(
                _running
                    ? 'Matching against local database...'
                    : 'Identify Species / Lineage',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Matching is performed offline against a curated local reference database (38 marker-gene records across bacteria, archaea, animals, plants, fungi, protists & viruses) using k-mer similarity — a BLAST-like heuristic. Use "Cross-check online" for authoritative results when connected.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          if (_domainResult != null) _DomainCard(result: _domainResult!),
          if (_domainResult != null) const SizedBox(height: 14),
          ..._matches.asMap().entries.map(
            (e) => _MatchCard(rank: e.key + 1, match: e.value),
          ),
          if (_matches.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _onlineChecking ? null : _crossCheckOnline,
              icon: _onlineChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.public),
              label: Text(
                _onlineChecking
                    ? 'Checking GBIF...'
                    : 'Cross-check best match online (GBIF)',
              ),
            ),
            if (_onlineResult != null)
              _OnlineResultCard(result: _onlineResult!),
          ],
        ],
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  final DomainClassificationResult result;
  const _DomainCard({required this.result});

  IconData _iconFor(String label) {
    switch (label) {
      case 'Human':
        return Icons.emoji_people_rounded;
      case 'Animal':
        return Icons.pets_rounded;
      case 'Plant':
        return Icons.local_florist_rounded;
      case 'Fungal':
        return Icons.grass_rounded;
      case 'Bacterial':
        return Icons.bubble_chart_rounded;
      case 'Viral':
        return Icons.coronavirus_rounded;
      case 'Archaeal':
        return Icons.whatshot_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.gradSpecies),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconFor(result.domainLabel),
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Domain / Origin: ',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                    Text(
                      result.domainLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  result.basis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${result.confidence.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final int rank;
  final SpeciesMatch match;
  const _MatchCard({required this.rank, required this.match});

  @override
  Widget build(BuildContext context) {
    final ref = match.reference;
    final lineage = ref.lineage.split(';');
    final conf = IdentificationEngine.confidenceLabel(match.similarityPercent);
    final confColor = match.similarityPercent >= 70
        ? AppColors.success
        : match.similarityPercent >= 40
        ? AppColors.warning
        : AppColors.danger;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: rank == 1
                      ? AppColors.success.withValues(alpha: 0.15)
                      : Colors.grey.shade200,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: rank == 1
                          ? AppColors.success
                          : Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.scientificName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text(
                        '${ref.commonName} · ${ref.markerGene}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${match.similarityPercent.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      conf,
                      style: TextStyle(
                        fontSize: 10,
                        color: confColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (match.similarityPercent / 100).clamp(0, 1),
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(confColor),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: lineage
                  .map(
                    (l) => Chip(
                      label: Text(l, style: const TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: const Color(0xFFE8F5E9),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _OnlineResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.gradOnline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.public, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'GBIF Live Cross-Check',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Matched taxon: ${result['scientificName'] ?? 'N/A'}',
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
          Text(
            'Rank: ${result['rank'] ?? 'N/A'}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            'Match confidence: ${result['confidence'] ?? 'N/A'}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
