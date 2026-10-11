import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/workflow_result.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../widgets/export_menu_button.dart';

/// Shows every [WorkflowResultRecord] produced by the Smart Workflow,
/// scoped to the signed-in account (so each user only ever sees their own
/// results). The super-administrator additionally sees a toggle to view
/// every user's results on this installation, consistent with the Admin
/// Dashboard's "see everything" behaviour.
class MyResultsScreen extends StatefulWidget {
  const MyResultsScreen({super.key});

  @override
  State<MyResultsScreen> createState() => _MyResultsScreenState();
}

class _MyResultsScreenState extends State<MyResultsScreen> {
  bool _showAllUsers = false;

  List<WorkflowResultRecord> _load(AuthService auth) {
    final all = StorageService.loadAllWorkflowResults();
    if (auth.isSuperAdmin && _showAllUsers) return all;
    final uid = auth.currentUser?.id;
    if (uid == null) return [];
    return all.where((r) => r.ownerId == uid).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final results = _load(auth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Results'),
        actions: [
          if (auth.isSuperAdmin)
            IconButton(
              tooltip: _showAllUsers ? 'Show only my results' : 'Show every user\'s results',
              icon: Icon(_showAllUsers ? Icons.person : Icons.groups_rounded),
              onPressed: () => setState(() => _showAllUsers = !_showAllUsers),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: results.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 64, color: Color(0xFFE1BEE7)),
                    const SizedBox(height: 16),
                    const Text(
                      'No workflow results yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Run a Smart Workflow (check the analyses you want, run them, and the '
                      'combined result will show up here, linked to your account).',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              itemCount: results.length,
              itemBuilder: (context, i) {
                final r = results[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF3E5F5),
                      child: Icon(Icons.auto_awesome, color: Color(0xFF6A1B9A), size: 20),
                    ),
                    title: Text(
                      r.sequenceName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    subtitle: Text(
                      '${r.taskLabels.join(", ")} · ${DateFormat('dd/MM/yyyy HH:mm').format(r.createdAt)}'
                      '${_showAllUsers && auth.isSuperAdmin ? ' · ${r.ownerEmail}' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: ExportMenuButton(
                          reportBuilder: () => r.reportData,
                          moduleType: 'Smart Workflow',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...r.reportData.sections.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                              ),
                              if (s.bodyText != null) ...[
                                const SizedBox(height: 4),
                                Text(s.bodyText!, style: const TextStyle(fontSize: 11.5, height: 1.4)),
                              ],
                              if (s.table != null) ...[
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowHeight: 30,
                                    dataRowMinHeight: 26,
                                    dataRowMaxHeight: 40,
                                    columns: s.table!.first
                                        .map(
                                          (h) => DataColumn(
                                            label: Text(
                                              h,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    rows: s.table!
                                        .skip(1)
                                        .map(
                                          (row) => DataRow(
                                            cells: row
                                                .map(
                                                  (c) => DataCell(
                                                    Text(c, style: const TextStyle(fontSize: 10.5)),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
