import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bio_sequence.dart';
import '../services/app_state.dart';
import '../screens/projects_screen.dart';

/// Compact pill button showing the currently active project, used in
/// AppBars across analysis modules. Tapping it opens a quick-switch menu
/// plus a shortcut into the full Projects management screen — this is how
/// every screen stays scoped to "one project's sequences at a time"
/// without impacting the data of other projects.
class ProjectSwitcher extends StatelessWidget {
  const ProjectSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final active = appState.activeProject;
    final color = Color(active.colorValue);

    return PopupMenuButton<String>(
      tooltip: 'Switch project',
      onSelected: (value) {
        if (value == '__manage__') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen()));
        } else {
          context.read<AppState>().setActiveProject(value);
        }
      },
      itemBuilder: (context) => [
        ...appState.projects.map(
          (p) => PopupMenuItem<String>(
            value: p.id,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: Color(p.colorValue), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: p.id == active.id ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                if (p.id == active.id) const Icon(Icons.check, size: 16, color: Color(0xFF1565C0)),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__manage__',
          child: Row(
            children: [
              Icon(Icons.folder_special_outlined, size: 18),
              SizedBox(width: 10),
              Text('Manage projects...'),
            ],
          ),
        ),
      ],
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_rounded, size: 15, color: color),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                active.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

class ProjectUtil {
  /// Resolves the active project's sequence list, convenience wrapper used
  /// by modules that want a one-liner instead of repeating the getter.
  static List<BioSequence> activeSequences(BuildContext context) =>
      context.watch<AppState>().sequencesInActiveProject;
}
