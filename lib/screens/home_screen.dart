import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/module_card.dart';
import '../widgets/connectivity_badge.dart';
import 'sequence_library_screen.dart';
import 'primer_design_screen.dart';
import 'alignment_screen.dart';
import 'phylo_tree_screen.dart';
import 'species_id_screen.dart';
import 'quality_control_screen.dart';
import 'statistics_screen.dart';
import 'online_tools_hub_screen.dart';
import 'assistant_screen.dart';
import 'reports_screen.dart';
import 'sequencing_raw_screen.dart';
import 'rna_analysis_screen.dart';
import 'proteomics_screen.dart';
import 'annotation_screen.dart';
import 'structure3d_screen.dart';
import 'target_analysis_screen.dart';
import 'metabolomics_screen.dart';

/// Icon/tile density presets for the module grid — lets users on
/// desktop/tablet screens re-size module icons as requested, persisted via
/// [AppState.setIconDensity].
class _DensityPreset {
  final double iconBoxSize;
  final double iconSize;
  final double titleFontSize;
  final double subtitleFontSize;
  final double padding;
  final double aspectRatio;
  const _DensityPreset({
    required this.iconBoxSize,
    required this.iconSize,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.padding,
    required this.aspectRatio,
  });
}

const Map<String, _DensityPreset> _densityPresets = {
  'compact': _DensityPreset(
    iconBoxSize: 36,
    iconSize: 19,
    titleFontSize: 12.5,
    subtitleFontSize: 10,
    padding: 12,
    aspectRatio: 1.08,
  ),
  'comfortable': _DensityPreset(
    iconBoxSize: 46,
    iconSize: 24,
    titleFontSize: 14.5,
    subtitleFontSize: 11.5,
    padding: 16,
    aspectRatio: 0.92,
  ),
  'large': _DensityPreset(
    iconBoxSize: 60,
    iconSize: 31,
    titleFontSize: 16.5,
    subtitleFontSize: 12.5,
    padding: 20,
    aspectRatio: 0.82,
  ),
};

/// A module entry used to build the responsive grid declaratively.
class _ModuleEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final WidgetBuilder builder;
  const _ModuleEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.builder,
  });
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Responsive column count: this app targets desktop/tablet first, so we
  /// give it more columns than a typical phone-first design as soon as
  /// there is room, only falling back to a narrow 2-column phone layout.
  int _columnsFor(double width) {
    if (width >= 1300) return 5;
    if (width >= 1000) return 4;
    if (width >= 680) return 3;
    return 2;
  }

  List<List<_ModuleEntry>> _sections(BuildContext context) => [
    [
      _ModuleEntry(
        title: 'Sequence Library',
        subtitle: 'Upload, paste & manage FASTA/FASTQ',
        icon: Icons.dns_rounded,
        gradient: AppColors.gradSequence,
        builder: (_) => const SequenceLibraryScreen(),
      ),
      _ModuleEntry(
        title: 'Raw Sequencing Data',
        subtitle: 'Illumina / ONT / PacBio / Sanger → FASTA/FASTQ',
        icon: Icons.memory_rounded,
        gradient: AppColors.gradSequencing,
        builder: (_) => const SequencingRawScreen(),
      ),
      _ModuleEntry(
        title: 'Quality Control',
        subtitle: 'Phred scores, GC%, N-content',
        icon: Icons.verified_rounded,
        gradient: AppColors.gradQuality,
        builder: (_) => const QualityControlScreen(),
      ),
    ],
    [
      _ModuleEntry(
        title: 'Primer Design',
        subtitle: 'Tm, GC%, hairpin & dimer checks',
        icon: Icons.biotech_rounded,
        gradient: AppColors.gradPrimer,
        builder: (_) => const PrimerDesignScreen(),
      ),
      _ModuleEntry(
        title: 'Sequence Alignment',
        subtitle: 'Pairwise & multiple alignment',
        icon: Icons.align_horizontal_left_rounded,
        gradient: AppColors.gradAlignment,
        builder: (_) => const AlignmentScreen(),
      ),
      _ModuleEntry(
        title: 'Phylogenetic Tree',
        subtitle: 'UPGMA & Neighbor-Joining trees',
        icon: Icons.account_tree_rounded,
        gradient: AppColors.gradPhylo,
        builder: (_) => const PhyloTreeScreen(),
      ),
      _ModuleEntry(
        title: 'Species / Variant ID',
        subtitle: 'Lineage, taxonomy & domain-of-life ID',
        icon: Icons.pets_rounded,
        gradient: AppColors.gradSpecies,
        builder: (_) => const SpeciesIdScreen(),
      ),
    ],
    [
      _ModuleEntry(
        title: 'RNA Analysis',
        subtitle: 'Transcription, RNA class ID & folding',
        icon: Icons.change_history_rounded,
        gradient: AppColors.gradRna,
        builder: (_) => const RnaAnalysisScreen(),
      ),
      _ModuleEntry(
        title: 'Proteomics',
        subtitle: 'Translation, MW, pI, GRAVY & composition',
        icon: Icons.science_rounded,
        gradient: AppColors.gradProteomics,
        builder: (_) => const ProteomicsScreen(),
      ),
      _ModuleEntry(
        title: 'Annotations',
        subtitle: 'ORF finder, custom features & GFF3 export',
        icon: Icons.label_important_rounded,
        gradient: AppColors.gradAnnotation,
        builder: (_) => const AnnotationScreen(),
      ),
      _ModuleEntry(
        title: '3D Structure & Stability',
        subtitle: 'Idealized 3D models & stability indicators',
        icon: Icons.view_in_ar_rounded,
        gradient: AppColors.gradStructure3D,
        builder: (_) => const Structure3DScreen(),
      ),
      _ModuleEntry(
        title: 'Therapeutic & Vaccine Targets',
        subtitle: 'Epitope & transmembrane triage',
        icon: Icons.vaccines_rounded,
        gradient: AppColors.gradTargets,
        builder: (_) => const TargetAnalysisScreen(),
      ),
      _ModuleEntry(
        title: 'Metabolomics',
        subtitle: 'Formula mass, metabolite explorer & mass ID',
        icon: Icons.opacity_rounded,
        gradient: AppColors.gradMetabolomics,
        builder: (_) => const MetabolomicsScreen(),
      ),
    ],
    [
      _ModuleEntry(
        title: 'Statistics Lab',
        subtitle: 'Descriptive stats & diversity index',
        icon: Icons.bar_chart_rounded,
        gradient: AppColors.gradStats,
        builder: (_) => const StatisticsScreen(),
      ),
      _ModuleEntry(
        title: 'Online Tools Hub',
        subtitle: 'NCBI, EBI, UniProt, GBIF & more',
        icon: Icons.public_rounded,
        gradient: AppColors.gradOnline,
        builder: (_) => const OnlineToolsHubScreen(),
      ),
    ],
  ];

  static const List<String> _sectionTitles = [
    'Sequence Data & Quality',
    'Core Analysis',
    'Molecular Biology',
    'Insights & Resources',
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final seqCount = appState.sequences.length;
    final reportCount = appState.reportHistory.length;
    final density =
        _densityPresets[appState.iconDensity] ??
        _densityPresets['comfortable']!;
    final sections = _sections(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HeroHeader(seqCount: seqCount, reportCount: reportCount),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    // On ultra-wide desktop monitors, cap & center the
                    // content instead of stretching the grid edge-to-edge
                    // (which otherwise leaves a large lopsided empty gap
                    // on the right once the column count maxes out).
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = _columnsFor(constraints.maxWidth);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Analysis Modules',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Everything you need, from raw reads to publication-ready reports. '
                                        'Optimized for desktop & tablet — resize the window or adjust tile size below.',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _DensitySelector(current: appState.iconDensity),
                              ],
                            ),
                            const SizedBox(height: 16),
                            for (int s = 0; s < sections.length; s++) ...[
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: 10,
                                  top: s == 0 ? 0 : 22,
                                ),
                                child: Text(
                                  _sectionTitles[s],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              GridView.count(
                                crossAxisCount: columns,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: density.aspectRatio,
                                children: sections[s]
                                    .map(
                                      (m) => ModuleCard(
                                        title: m.title,
                                        subtitle: m.subtitle,
                                        icon: m.icon,
                                        gradient: m.gradient,
                                        iconBoxSize: density.iconBoxSize,
                                        iconSize: density.iconSize,
                                        titleFontSize: density.titleFontSize,
                                        subtitleFontSize:
                                            density.subtitleFontSize,
                                        padding: density.padding,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: m.builder),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            const SizedBox(height: 24),
                            _AssistantBanner(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AssistantScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ReportsShortcut(
                              count: reportCount,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReportsScreen(),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact 3-way icon-size control (Compact / Comfortable / Large),
/// persisted via [AppState.setIconDensity] — fulfils the adjustable module
/// icon-size requirement.
class _DensitySelector extends StatelessWidget {
  final String current;
  const _DensitySelector({required this.current});

  @override
  Widget build(BuildContext context) {
    Widget btn(String key, IconData icon, String tooltip) {
      final selected = current == key;
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => context.read<AppState>().setIconDensity(key),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn('compact', Icons.grid_view_rounded, 'Compact tiles'),
          btn('comfortable', Icons.apps_rounded, 'Comfortable tiles'),
          btn('large', Icons.dashboard_customize_rounded, 'Large tiles'),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final int seqCount;
  final int reportCount;
  const _HeroHeader({required this.seqCount, required this.reportCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.biotech,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Genome Analyzer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const ConnectivityBadge(),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Your all-in-one\nbioinformatics workbench',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatChip(
                label: 'Sequences',
                value: '$seqCount',
                icon: Icons.dns_rounded,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Reports',
                value: '$reportCount',
                icon: Icons.description_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AssistantBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AssistantBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.gradAssistant),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.gradAssistant.first.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Ask the Smart Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '"Design primers for my COI sequence" · "Align seq1 and seq2"',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ReportsShortcut extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _ReportsShortcut({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.gradReports),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.folder_copy_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reports & Export Center',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Text(
                    '$count report${count == 1 ? '' : 's'} generated',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
