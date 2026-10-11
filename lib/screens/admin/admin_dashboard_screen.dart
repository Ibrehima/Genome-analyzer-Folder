import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/activity_log.dart';
import '../../models/user_account.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

/// Super-admin only dashboard: visible exclusively to the account whose
/// email matches [kSuperAdminEmail] (guindo50@gmail.com). Shows every
/// registered account and every recorded activity on this installation,
/// plus aggregate statistics (per-module usage, daily activity, user
/// breakdown).
///
/// HONESTY NOTE: data shown here is local to this device/browser (Hive
/// storage) — there is no Firebase/cloud backend configured for this build,
/// so this reflects activity recorded on this installation only, not a
/// true cross-device view of every Genome Analyzer user. See AuthService.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthService>().refreshAdminData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final users = auth.allUsers;
    final activity = auth.activityLog;

    final Map<String, int> perModule = {};
    for (final a in activity) {
      perModule[a.module] = (perModule[a.module] ?? 0) + 1;
    }
    final Map<String, int> perUser = {};
    for (final a in activity) {
      perUser[a.userEmail] = (perUser[a.userEmail] ?? 0) + 1;
    }
    final sortedModules = perModule.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedUsers = perUser.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord administrateur'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AuthService>().refreshAdminData(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Super administrateur',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  "Vue d'ensemble de tous les comptes et activités enregistrés sur cette "
                  "installation de Genome Analyzer. Aucun serveur cloud n'étant configuré, "
                  "ces données sont stockées localement sur cet appareil/navigateur.",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Utilisateurs inscrits',
                  value: '${users.length}',
                  icon: Icons.people_alt_rounded,
                  gradient: AppColors.gradSpecies,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Activités enregistrées',
                  value: '${activity.length}',
                  icon: Icons.timeline_rounded,
                  gradient: AppColors.gradStats,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "Activité par module",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          const SizedBox(height: 10),
          if (sortedModules.isEmpty)
            const _EmptyHint(text: 'Aucune activité enregistrée pour le moment.')
          else
            _ModuleBarChart(data: sortedModules),
          const SizedBox(height: 24),
          const Text(
            'Utilisateurs les plus actifs',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          const SizedBox(height: 10),
          if (sortedUsers.isEmpty)
            const _EmptyHint(text: 'Aucun utilisateur actif pour le moment.')
          else
            Card(
              child: Column(
                children: sortedUsers
                    .take(10)
                    .map(
                      (e) => ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(e.key, style: const TextStyle(fontSize: 13)),
                        trailing: Text(
                          '${e.value} action${e.value > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'Comptes enregistrés',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          const SizedBox(height: 10),
          if (users.isEmpty)
            const _EmptyHint(text: 'Aucun compte enregistré.')
          else
            Card(
              child: Column(
                children: users.map((u) => _UserTile(user: u)).toList(),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'Journal des activités (toutes)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          const SizedBox(height: 10),
          if (activity.isEmpty)
            const _EmptyHint(text: 'Aucune activité à afficher.')
          else
            Card(
              child: Column(
                children: activity.take(50).map((a) => _ActivityTile(entry: a)).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
          ),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _ModuleBarChart extends StatelessWidget {
  final List<MapEntry<String, int>> data;
  const _ModuleBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final top = data.take(8).toList();
    final maxY = top.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
        child: SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY <= 0 ? 1 : maxY * 1.2,
              barGroups: [
                for (int i = 0; i < top.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: top[i].value.toDouble(),
                        color: AppColors.primaryBlue,
                        width: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= top.length) return const SizedBox.shrink();
                      final label = top[idx].key;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label.length > 8 ? '${label.substring(0, 8)}…' : label,
                          style: const TextStyle(fontSize: 9.5),
                        ),
                      );
                    },
                    reservedSize: 32,
                  ),
                ),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserAccount user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: user.isSuperAdmin
            ? AppColors.gradTargets.first
            : AppColors.gradSequence.first,
        child: Icon(
          user.isSuperAdmin ? Icons.admin_panel_settings : Icons.person,
          color: Colors.white,
          size: 18,
        ),
      ),
      title: Text(user.email, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${user.institution.isEmpty ? '—' : user.institution} · ${user.city.isEmpty ? '—' : user.city}, '
        '${user.country.isEmpty ? '—' : user.country} · ${user.occupation == OccupationType.professional ? 'Professionnel' : 'Étudiant'}'
        '${user.specialty.isEmpty ? '' : ' · ${user.specialty}'}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Text(
        DateFormat('dd/MM/yyyy').format(user.createdAt),
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityLogEntry entry;
  const _ActivityTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.bolt_rounded, size: 18, color: AppColors.primaryBlue),
      title: Text(
        '${entry.module} — ${entry.action}',
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(entry.userEmail, style: const TextStyle(fontSize: 11)),
      trailing: Text(
        DateFormat('dd/MM HH:mm').format(entry.timestamp),
        style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
    );
  }
}
