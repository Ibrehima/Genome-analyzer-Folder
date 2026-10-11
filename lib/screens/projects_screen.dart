import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bio_sequence.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';

const List<int> _projectColorChoices = [
  0xFF1565C0,
  0xFF00897B,
  0xFF7B1FA2,
  0xFFEF6C00,
  0xFF2E7D32,
  0xFFC2185B,
  0xFF4527A0,
  0xFF37474F,
];

/// Project management: create new isolated workspaces ("projects"), each
/// acting as a folder that holds its own set of sequences so that
/// uploading/processing data in one project never impacts another.
/// Switching the active project here changes what every analysis module
/// (Library, Alignment, Contig Assembly, etc.) sees and operates on.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  Future<void> _showProjectDialog({Project? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    int color = existing?.colorValue ?? _projectColorChoices.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? 'New Project' : 'Rename Project',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'A project is an isolated folder of sequences — data '
                    'added or processed in one project never affects another.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Project name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Accent color',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: _projectColorChoices.map((c) {
                      final selected = c == color;
                      return InkWell(
                        onTap: () => setDialogState(() => color = c),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: selected ? Border.all(color: Colors.black87, width: 2.5) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final appState = context.read<AppState>();
                          if (existing == null) {
                            final p = await appState.createProject(
                              nameCtrl.text,
                              description: descCtrl.text.trim(),
                              colorValue: color,
                            );
                            await appState.setActiveProject(p.id);
                          } else {
                            await appState.renameProject(
                              existing.id,
                              nameCtrl.text,
                              description: descCtrl.text.trim(),
                            );
                            existing.colorValue = color;
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(existing == null ? 'Create' : 'Save'),
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

  Future<void> _confirmDelete(Project p, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          'This will permanently delete "${p.name}" and its $count '
          'sequence(s). Sequences in other projects are not affected. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppState>().deleteProject(p.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final projects = appState.projects;

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProjectDialog(),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('New Project'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Projects keep your work separated: each project has its own '
                    'sequences. Upload, trim, assemble or align sequences inside '
                    'a project without ever affecting another project\'s data. '
                    'Tap a project to make it active everywhere in the app.',
                    style: TextStyle(fontSize: 12, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...projects.map((p) {
            final isActive = p.id == appState.activeProjectId;
            final count = appState.sequenceCountFor(p.id);
            final color = Color(p.colorValue);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isActive
                    ? BorderSide(color: color, width: 1.6)
                    : BorderSide(color: Colors.grey.shade200),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.read<AppState>().setActiveProject(p.id),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.folder_rounded, color: color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                if (isActive) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (p.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  p.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              '$count sequence${count == 1 ? '' : 's'}',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'rename') {
                            _showProjectDialog(existing: p);
                          } else if (v == 'delete') {
                            _confirmDelete(p, count);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'rename', child: Text('Rename / edit')),
                          if (p.id != Project.defaultId)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete project',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
