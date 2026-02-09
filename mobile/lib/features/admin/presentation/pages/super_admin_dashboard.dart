import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/secure_storage.dart';
import 'organization_detail_page.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({Key? key}) : super(key: key);

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<dynamic> _organizations = [];
  List<dynamic> _sessions = [];
  List<dynamic> _failedLogins = [];
  List<dynamic> _errorLogs = [];
  List<dynamic> _activity = [];
  List<dynamic> _alerts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
    _loadData();
  }

  Future<Map<String, String>> _getHeaders() async {
    final storage = SecureStorage();
    final token = await storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadStats(),
        _loadOrganizations(),
        _loadSessions(),
        _loadFailedLogins(),
        _loadErrorLogs(),
        _loadActivity(),
        _loadAlerts(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(ApiConstants.superAdminStats),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() => _stats = data['data']);
    }
  }

  Future<void> _loadOrganizations() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(ApiConstants.superAdminOrgs),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() => _organizations = data['data']);
    }
  }

  Future<void> _loadSessions() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/super-admin/sessions'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() => _sessions = data['data']);
    }
  }

  Future<void> _loadFailedLogins() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/super-admin/security/failed-logins/detailed?hours=24'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() => _failedLogins = data['data']);
    }
  }

  Future<void> _loadErrorLogs() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/super-admin/logs/detailed?limit=50'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() => _errorLogs = data['data']);
    }
  }

  Future<void> _loadActivity() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/super-admin/activity/detailed?limit=50'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() => _activity = data['data']);
    }
  }

  Future<void> _loadAlerts() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/super-admin/alerts'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() => _alerts = data['data']);
    }
  }

  Future<void> _revokeSession(String sessionId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/super-admin/sessions/$sessionId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session révoquée')),
      );
      _loadSessions();
    }
  }

  Future<void> _triggerBackup() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/super-admin/backup'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup créé: ${data['filename']}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showGlobalSearch,
            tooltip: 'Recherche globale',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Organisations'),
            Tab(text: 'Sessions'),
            Tab(text: 'Sécurité'),
            Tab(text: 'Logs'),
            Tab(text: 'Activité'),
            Tab(text: 'Alertes'),
            Tab(text: 'Monitoring'),
            Tab(text: 'Rapports'),
            Tab(text: 'Paramètres'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboard(),
                _buildOrganizations(),
                _buildSessions(),
                _buildSecurity(),
                _buildLogs(),
                _buildActivity(),
                _buildAlerts(),
                _buildMonitoring(),
                _buildReports(),
                _buildSettings(),
              ],
            ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final storage = SecureStorage();
      await storage.clearAll();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  Widget _buildDashboard() {
    if (_stats == null) return const Center(child: Text('Aucune donnée'));

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAdvancedStats,
                  icon: const Icon(Icons.analytics),
                  label: const Text('Stats avancées'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showDashboardCharts,
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Graphiques'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildStatCard('Organisations', _stats!['totalOrganizations'].toString(), Icons.business, Colors.blue),
          _buildStatCard('Organisations actives', _stats!['activeOrganizations'].toString(), Icons.check_circle, Colors.green),
          _buildStatCard('Utilisateurs', _stats!['totalUsers'].toString(), Icons.people, Colors.orange),
          _buildStatCard('Commandes totales', _stats!['totalOrders'].toString(), Icons.shopping_cart, Colors.purple),
          const Divider(height: 32),
          Text('Aujourd\'hui', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _buildStatCard('Commandes', _stats!['ordersToday'].toString(), Icons.today, Colors.indigo),
          _buildStatCard('Chiffre d\'affaires', '${_stats!['revenueToday']} DA', Icons.attach_money, Colors.teal),
          _buildStatCard('Utilisateurs actifs (24h)', _stats!['activeUsers24h'].toString(), Icons.person_outline, Colors.cyan),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _triggerBackup,
                  icon: const Icon(Icons.backup),
                  label: const Text('Backup'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _checkSystemHealth,
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Santé'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildOrganizations() {
    return RefreshIndicator(
      onRefresh: _loadOrganizations,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showCreateOrgDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Créer'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showArchivedOrganizations,
                    icon: const Icon(Icons.archive),
                    label: const Text('Archivées'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _organizations.length,
              itemBuilder: (context, index) {
                final org = _organizations[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: org['active'] ? Colors.green : Colors.grey,
                      child: Text(org['name'][0].toUpperCase()),
                    ),
                    title: Text(org['name']),
                    subtitle: Text('Type: ${org['type']} • ${org['active'] ? 'Active' : 'Inactive'}'),
                    trailing: PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: ListTile(
                            leading: const Icon(Icons.info),
                            title: const Text('Voir détails'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrganizationDetailPage(
                                  organizationId: org['id'],
                                  organizationName: org['name'],
                                ),
                              ),
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          child: ListTile(
                            leading: const Icon(Icons.copy),
                            title: const Text('Dupliquer'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _showDuplicateOrgDialog(org),
                          ),
                        ),
                        PopupMenuItem(
                          child: ListTile(
                            leading: const Icon(Icons.people),
                            title: const Text('Utilisateurs'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _showOrgUsers(org['id'], org['name']),
                          ),
                        ),
                        PopupMenuItem(
                          child: ListTile(
                            leading: const Icon(Icons.bar_chart),
                            title: const Text('Statistiques'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _showOrgStats(org['id'], org['name']),
                          ),
                        ),
                        PopupMenuItem(
                          child: ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('Modifier'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _showEditOrgDialog(org),
                          ),
                        ),
                        PopupMenuItem(
                          child: ListTile(
                            leading: Icon(org['active'] ? Icons.block : Icons.check_circle),
                            title: Text(org['active'] ? 'Désactiver' : 'Activer'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _toggleOrgStatus(org['id'], !org['active']),
                          ),
                        ),
                        PopupMenuItem(
                          child: ListTile(
                            leading: Icon(org['active'] ? Icons.archive : Icons.unarchive),
                            title: Text(org['active'] ? 'Archiver' : 'Restaurer'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => org['active'] 
                                ? _archiveOrganization(org['id'], org['name'])
                                : _restoreOrganization(org['id'], org['name']),
                          ),
                        ),
                        PopupMenuItem(
                          child: const ListTile(
                            leading: Icon(Icons.show_chart),
                            title: Text('Voir croissance'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _showGrowthChart(org['id']),
                          ),
                        ),
                        PopupMenuItem(
                          child: const ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Supprimer', style: TextStyle(color: Colors.red)),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _confirmDeleteOrg(org['id'], org['name']),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessions() {
    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(session['role'][0].toUpperCase()),
              ),
              title: Text(session['name'] ?? session['email']),
              subtitle: Text('${session['organization_name']}\n${session['email']}'),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmRevokeSession(session['id']),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSecurity() {
    return RefreshIndicator(
      onRefresh: _loadFailedLogins,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showBlockedIPs,
                  icon: const Icon(Icons.block),
                  label: const Text('IPs bloquées'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _purgeFailedLogins,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Purger'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Liste des tentatives échouées
          if (_failedLogins.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucune tentative échouée récente'),
              ),
            )
          else
            ..._failedLogins.map((login) => Card(
                  color: Colors.red.shade50,
                  child: ExpansionTile(
                    leading: const Icon(Icons.warning, color: Colors.red),
                    title: Text(login['email'] ?? 'Inconnu'),
                    subtitle: Text('${login['attempts']} tentatives'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Adresse IP', login['ip'] ?? 'N/A'),
                            _buildDetailRow('Première tentative', 
                                login['first_attempt']?.substring(0, 19) ?? 'N/A'),
                            _buildDetailRow('Dernière tentative', 
                                login['last_attempt']?.substring(0, 19) ?? 'N/A'),
                            _buildDetailRow('Raisons', 
                                (login['reasons'] as List?)?.join(', ') ?? 'N/A'),
                            _buildDetailRow('Navigateur', 
                                login['user_agent']?.substring(0, 50) ?? 'N/A'),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _blockIP(login['ip'], login['email']),
                              icon: const Icon(Icons.block),
                              label: const Text('Bloquer cette IP'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _blockIP(String? ip, String? email) async {
    if (ip == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bloquer cette IP'),
        content: Text('Voulez-vous bloquer l\'IP $ip (${email ?? 'Inconnu'})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bloquer 24h'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/super-admin/security/block-ip'),
          headers: headers,
          body: json.encode({
            'ip': ip,
            'duration': 'temporary',
            'reason': 'Tentatives de connexion suspectes depuis $email',
          }),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('IP $ip bloquée pour 24h')),
          );
          _loadFailedLogins();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _showBlockedIPs() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/security/blocked-ips'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final blockedIPs = data['data'] as List<dynamic>;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('IPs bloquées'),
            content: SizedBox(
              width: double.maxFinite,
              child: blockedIPs.isEmpty
                  ? const Text('Aucune IP bloquée')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: blockedIPs.length,
                      itemBuilder: (context, index) {
                        final ip = blockedIPs[index];
                        return ListTile(
                          leading: const Icon(Icons.block, color: Colors.red),
                          title: Text(ip['ip_address']),
                          subtitle: Text(ip['reason'] ?? 'Aucune raison'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _unblockIP(ip['ip_address']),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _unblockIP(String ip) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/security/unblock-ip/$ip'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('IP $ip débloquée')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _purgeFailedLogins() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purger les tentatives échouées'),
        content: const Text('Supprimer toutes les tentatives de plus de 30 jours?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Purger', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final headers = await _getHeaders();
        final response = await http.delete(
          Uri.parse('${ApiConstants.baseUrl}/super-admin/security/purge-failed-logins'),
          headers: headers,
          body: json.encode({'older_than_days': 30}),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
          _loadFailedLogins();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Widget _buildLogs() {
    return RefreshIndicator(
      onRefresh: _loadErrorLogs,
      child: Column(
        children: [
          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showLogsFilters,
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Filtres'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _purgeLogs,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Purger'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
          
          // Liste des logs
          Expanded(
            child: _errorLogs.isEmpty
                ? const Center(child: Text('Aucun log d\'erreur'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _errorLogs.length,
                    itemBuilder: (context, index) {
                      final log = _errorLogs[index];
                      return Card(
                        color: Colors.orange.shade50,
                        child: ExpansionTile(
                          leading: const Icon(Icons.error_outline, color: Colors.orange),
                          title: Text(log['action']),
                          subtitle: Text(
                            '${log['organization_name'] ?? 'N/A'} • '
                            '${log['created_at']?.substring(0, 19) ?? 'N/A'}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow('Organisation', log['organization_name'] ?? 'N/A'),
                                  _buildDetailRow('Utilisateur', log['user_name'] ?? 'Système'),
                                  _buildDetailRow('Email', log['user_email'] ?? 'N/A'),
                                  _buildDetailRow('Rôle', log['user_role'] ?? 'N/A'),
                                  _buildDetailRow('Adresse IP', log['ip_address'] ?? 'N/A'),
                                  _buildDetailRow('Navigateur', 
                                      log['user_agent']?.substring(0, 50) ?? 'N/A'),
                                  _buildDetailRow('Date complète', log['created_at'] ?? 'N/A'),
                                  if (log['details'] != null) ...[
                                    const SizedBox(height: 8),
                                    const Text('Détails:', 
                                        style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text(log['details'].toString()),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmRevokeSession(String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Révoquer session'),
        content: const Text('Êtes-vous sûr de vouloir révoquer cette session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _revokeSession(sessionId);
            },
            child: const Text('Révoquer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ============================================
  // GESTION DES ORGANISATIONS
  // ============================================

  void _showCreateOrgDialog() {
    final nameController = TextEditingController();
    final typeController = TextEditingController(text: 'restaurant');
    final adminEmailController = TextEditingController();
    final adminPasswordController = TextEditingController();
    final adminNameController = TextEditingController();
    final adminPhoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer une organisation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'organisation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  hintText: 'restaurant, pizzeria, etc.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: adminEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email Admin',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: adminPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe Admin (min 6)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: adminNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom Admin',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: adminPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone Admin (optionnel)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  adminEmailController.text.isEmpty ||
                  adminPasswordController.text.isEmpty ||
                  adminNameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tous les champs sont requis')),
                );
                return;
              }

              Navigator.pop(context);
              await _createOrganization(
                name: nameController.text,
                type: typeController.text,
                adminEmail: adminEmailController.text,
                adminPassword: adminPasswordController.text,
                adminName: adminNameController.text,
                adminPhone: adminPhoneController.text,
              );
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  Future<void> _createOrganization({
    required String name,
    required String type,
    required String adminEmail,
    required String adminPassword,
    required String adminName,
    required String adminPhone,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConstants.superAdminOrgs),
        headers: headers,
        body: json.encode({
          'name': name,
          'type': type,
          'adminEmail': adminEmail,
          'adminPassword': adminPassword,
          'adminName': adminName,
          'adminPhone': adminPhone,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organisation créée avec succès')),
        );
        _loadOrganizations();
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${error['error'] ?? 'Inconnue'}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _showEditOrgDialog(Map<String, dynamic> org) {
    final nameController = TextEditingController(text: org['name']);
    final typeController = TextEditingController(text: org['type']);
    final kitchenModeValue = org['kitchen_mode'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier l\'organisation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Mode Cuisine'),
                subtitle: const Text('Activer la validation par la cuisine'),
                value: kitchenModeValue,
                onChanged: (value) {
                  setState(() {
                    org['kitchen_mode'] = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _updateOrganization(
                  org['id'],
                  name: nameController.text,
                  type: typeController.text,
                  kitchenMode: org['kitchen_mode'],
                );
              },
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateOrganization(
    String orgId, {
    required String name,
    required String type,
    required bool kitchenMode,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/organizations/$orgId'),
        headers: headers,
        body: json.encode({
          'name': name,
          'type': type,
          'kitchenMode': kitchenMode,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organisation modifiée')),
        );
        _loadOrganizations();
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${error['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _toggleOrgStatus(String orgId, bool active) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/organizations/$orgId/status'),
        headers: headers,
        body: json.encode({'active': active}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Organisation ${active ? 'activée' : 'désactivée'}')),
        );
        _loadOrganizations();
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${error['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _confirmDeleteOrg(String orgId, String orgName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'organisation'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "$orgName"?\n\n'
          'Cette action est irréversible et supprimera:\n'
          '• Tous les utilisateurs\n'
          '• Toutes les commandes\n'
          '• Tous les produits\n'
          '• Toutes les données associées',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteOrganization(orgId);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrganization(String orgId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/organizations/$orgId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organisation supprimée')),
        );
        _loadOrganizations();
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${error['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _showGrowthChart(String orgId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Graphiques de croissance'),
        content: FutureBuilder(
          future: _loadGrowthData(orgId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Erreur: ${snapshot.error}');
            }
            final data = snapshot.data as Map<String, dynamic>?;
            if (data == null) return const Text('Aucune donnée');

            return SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Commandes: ${data['orders']?.length ?? 0} jours'),
                    Text('Nouveaux users: ${data['users']?.length ?? 0} jours'),
                    const SizedBox(height: 16),
                    const Text('Graphiques détaillés disponibles prochainement'),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadGrowthData(String orgId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/organizations/$orgId/growth?days=30'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================
  // NOUVEAUX ONGLETS
  // ============================================

  Widget _buildActivity() {
    return RefreshIndicator(
      onRefresh: _loadActivity,
      child: Column(
        children: [
          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showActivityFilters,
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Filtres'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showActivityStats,
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Statistiques'),
                  ),
                ),
              ],
            ),
          ),
          
          // Liste des activités
          Expanded(
            child: _activity.isEmpty
                ? const Center(child: Text('Aucune activité récente'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _activity.length,
                    itemBuilder: (context, index) {
                      final log = _activity[index];
                      return Card(
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(_getActionIcon(log['action']), color: Colors.blue),
                          ),
                          title: Text(log['action']),
                          subtitle: Text(
                            '${log['organization_name'] ?? 'N/A'} • '
                            '${log['user_name'] ?? 'Système'} • '
                            '${log['created_at']?.substring(0, 19) ?? 'N/A'}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow('Action', log['action']),
                                  _buildDetailRow('Organisation', log['organization_name'] ?? 'N/A'),
                                  _buildDetailRow('Utilisateur', log['user_name'] ?? 'Système'),
                                  _buildDetailRow('Email', log['user_email'] ?? 'N/A'),
                                  _buildDetailRow('Rôle', log['user_role'] ?? 'N/A'),
                                  _buildDetailRow('Adresse IP', log['ip_address'] ?? 'N/A'),
                                  _buildDetailRow('Date complète', log['created_at'] ?? 'N/A'),
                                  if (log['details'] != null) ...[
                                    const SizedBox(height: 8),
                                    const Text('Détails:', 
                                        style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text(log['details'].toString()),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlerts() {
    if (_alerts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('Aucune alerte', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _alerts.length,
        itemBuilder: (context, index) {
          final alert = _alerts[index];
          final color = _getAlertColor(alert['severity']);
          return Card(
            color: color.withOpacity(0.1),
            child: ListTile(
              leading: Icon(
                _getAlertIcon(alert['type']),
                color: color,
                size: 32,
              ),
              title: Text(
                alert['message'],
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(alert['timestamp']),
            ),
          );
        },
      ),
    );
  }

  IconData _getActionIcon(String action) {
    if (action.contains('LOGIN')) return Icons.login;
    if (action.contains('LOGOUT')) return Icons.logout;
    if (action.contains('CREATE')) return Icons.add;
    if (action.contains('UPDATE')) return Icons.edit;
    if (action.contains('DELETE')) return Icons.delete;
    if (action.contains('ERROR')) return Icons.error;
    return Icons.info;
  }

  Color _getAlertColor(String severity) {
    switch (severity) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'security':
        return Icons.security;
      case 'business':
        return Icons.business;
      case 'technical':
        return Icons.build;
      default:
        return Icons.warning;
    }
  }

  // ============================================
  // GESTION DES UTILISATEURS
  // ============================================

  void _showOrgUsers(String orgId, String orgName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Utilisateurs - $orgName'),
        content: FutureBuilder(
          future: _loadOrgUsers(orgId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Erreur: ${snapshot.error}');
            }
            final users = snapshot.data as List<dynamic>?;
            if (users == null || users.isEmpty) {
              return const Text('Aucun utilisateur');
            }

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: user['active'] ? Colors.green : Colors.grey,
                      child: Text(user['role'][0].toUpperCase()),
                    ),
                    title: Text(user['name']),
                    subtitle: Text(
                      '${user['email']}\n'
                      'Rôle: ${user['role']} • '
                      'Commandes: ${user['total_orders']} • '
                      'CA: ${user['total_revenue']} DA',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: ListTile(
                            leading: Icon(user['active'] ? Icons.block : Icons.check_circle),
                            title: Text(user['active'] ? 'Désactiver' : 'Activer'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _toggleUser(user['id'], !user['active']);
                          },
                        ),
                        PopupMenuItem(
                          child: const ListTile(
                            leading: Icon(Icons.lock_reset),
                            title: Text('Réinitialiser MDP'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _resetUserPassword(user['id'], user['name']);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<List<dynamic>> _loadOrgUsers(String orgId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/super-admin/organizations/$orgId/users'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'];
    }
    return [];
  }

  void _showOrgStats(String orgId, String orgName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Statistiques - $orgName'),
        content: FutureBuilder(
          future: _loadOrgStats(orgId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Erreur: ${snapshot.error}');
            }
            final stats = snapshot.data as Map<String, dynamic>?;
            if (stats == null) return const Text('Aucune donnée');

            final general = stats['general'];
            final recent = stats['recent'];
            final topCustomers = stats['topCustomers'] as List<dynamic>;

            return SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Général', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Utilisateurs: ${general['total_users']}'),
                    Text('Clients: ${general['customers']}'),
                    Text('Livreurs: ${general['deliverers']}'),
                    Text('Commandes: ${general['total_orders']}'),
                    Text('CA total: ${general['total_revenue']} DA'),
                    const Divider(height: 24),
                    Text('30 derniers jours', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Commandes: ${recent['orders_period']}'),
                    Text('CA: ${recent['revenue_period']} DA'),
                    Text('Clients actifs: ${recent['active_customers']}'),
                    const Divider(height: 24),
                    Text('Top 10 clients', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...topCustomers.map((customer) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${customer['name']}: ${customer['total_spent']} DA (${customer['order_count']} cmd)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadOrgStats(String orgId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/organizations/$orgId/stats?days=30'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _toggleUser(String userId, bool active) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/users/$userId/toggle'),
        headers: headers,
        body: json.encode({'active': active}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Utilisateur ${active ? 'activé' : 'désactivé'}')),
        );
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${error['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _resetUserPassword(String userId, String userName) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Réinitialiser MDP - $userName'),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(
            labelText: 'Nouveau mot de passe (min 6)',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mot de passe trop court')),
                );
                return;
              }

              Navigator.pop(context);
              await _performPasswordReset(userId, passwordController.text);
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  Future<void> _performPasswordReset(String userId, String newPassword) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/users/$userId/reset-password'),
        headers: headers,
        body: json.encode({'newPassword': newPassword}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe réinitialisé')),
        );
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${error['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  // ============================================
  // LOGS - FILTRES ET PURGE
  // ============================================

  void _showLogsFilters() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtres des logs'),
        content: const Text('Filtres avancés disponibles prochainement'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _purgeLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purger les logs'),
        content: const Text('Supprimer tous les logs d\'erreur de plus de 90 jours?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Purger', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final headers = await _getHeaders();
        final response = await http.delete(
          Uri.parse('${ApiConstants.baseUrl}/super-admin/logs/purge'),
          headers: headers,
          body: json.encode({
            'older_than_days': 90,
            'log_type': 'error',
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
          _loadErrorLogs();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  // ============================================
  // ACTIVITÉ - FILTRES ET STATISTIQUES
  // ============================================

  void _showActivityFilters() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtres d\'activité'),
        content: const Text('Filtres avancés disponibles prochainement'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showActivityStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/activity/detailed?limit=1000'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final stats = data['stats'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Statistiques d\'activité'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Actions par heure (24h)', 
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(stats['actions_per_hour'] as List<dynamic>).take(10).map((item) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${item['hour']?.substring(0, 13) ?? 'N/A'}: ${item['count']} actions',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    Text('Actions par organisation', 
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(stats['actions_by_org'] as List<dynamic>).map((item) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${item['org_name'] ?? 'N/A'}: ${item['count']} actions',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    Text('Utilisateurs les plus actifs', 
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(stats['most_active_users'] as List<dynamic>).map((item) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${item['user_name'] ?? 'N/A'}: ${item['count']} actions',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  // ============================================
  // PHASE 2 - RECHERCHE GLOBALE
  // ============================================

  void _showGlobalSearch() {
    final searchController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recherche globale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Rechercher...',
                hintText: 'Nom, email, téléphone, organisation',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text(
              'Recherche dans toutes les organisations',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (searchController.text.length >= 2) {
                Navigator.pop(context);
                _performGlobalSearch(searchController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Minimum 2 caractères')),
                );
              }
            },
            child: const Text('Rechercher'),
          ),
        ],
      ),
    );
  }

  Future<void> _performGlobalSearch(String query) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/search?q=${Uri.encodeComponent(query)}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['data'];
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Résultats pour "$query"'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Utilisateurs
                    if ((results['users'] as List).isNotEmpty) ...[
                      Text('Utilisateurs (${results['users'].length})',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...(results['users'] as List).map((user) => ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(user['name']),
                            subtitle: Text('${user['email']}\n${user['organization_name'] ?? 'N/A'}'),
                            isThreeLine: true,
                            dense: true,
                          )),
                      const Divider(),
                    ],
                    
                    // Organisations
                    if ((results['organizations'] as List).isNotEmpty) ...[
                      Text('Organisations (${results['organizations'].length})',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...(results['organizations'] as List).map((org) => ListTile(
                            leading: const Icon(Icons.business),
                            title: Text(org['name']),
                            subtitle: Text('Type: ${org['type']}'),
                            dense: true,
                          )),
                      const Divider(),
                    ],
                    
                    // Commandes
                    if ((results['orders'] as List).isNotEmpty) ...[
                      Text('Commandes (${results['orders'].length})',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...(results['orders'] as List).map((order) => ListTile(
                            leading: const Icon(Icons.shopping_cart),
                            title: Text('${order['total']} DA'),
                            subtitle: Text('${order['organization_name']}\n${order['customer_name']}'),
                            isThreeLine: true,
                            dense: true,
                          )),
                    ],
                    
                    if (data['total'] == 0)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Aucun résultat trouvé'),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  // ============================================
  // PHASE 2 - STATISTIQUES AVANCÉES
  // ============================================

  Future<void> _showAdvancedStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/stats/advanced?days=30'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final stats = data['data'];
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Statistiques avancées (30 jours)'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Taux de croissance
                    Card(
                      color: double.parse(stats['growth_rate']) >= 0 
                          ? Colors.green.shade50 
                          : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              double.parse(stats['growth_rate']) >= 0 
                                  ? Icons.trending_up 
                                  : Icons.trending_down,
                              color: double.parse(stats['growth_rate']) >= 0 
                                  ? Colors.green 
                                  : Colors.red,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Taux de croissance',
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('${stats['growth_rate']}%',
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: double.parse(stats['growth_rate']) >= 0 
                                          ? Colors.green 
                                          : Colors.red,
                                    )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Top organisations par CA
                    Text('Top organisations par chiffre d\'affaires',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(stats['top_orgs_by_revenue'] as List).map((org) => ListTile(
                          leading: CircleAvatar(
                            child: Text('${(stats['top_orgs_by_revenue'] as List).indexOf(org) + 1}'),
                          ),
                          title: Text(org['name']),
                          subtitle: Text('${org['orders_count']} commandes'),
                          trailing: Text('${org['total_revenue']} DA',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          dense: true,
                        )),
                    const Divider(height: 24),
                    
                    // Répartition par rôle
                    Text('Utilisateurs par rôle',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(stats['users_by_role'] as List).map((role) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(role['role']),
                              Text('${role['count']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )),
                    const Divider(height: 24),
                    
                    // Répartition par statut
                    Text('Commandes par statut',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(stats['orders_by_status'] as List).map((status) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(status['status']),
                              Text('${status['count']} (${status['revenue']} DA)',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  // ============================================
  // PHASE 7 - GRAPHIQUES VISUELS
  // ============================================

  Future<void> _showDashboardCharts() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/charts/dashboard?days=7'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final charts = data['data'];
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Graphiques du dashboard (7 jours)'),
            content: SizedBox(
              width: double.maxFinite,
              height: 600,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Évolution des commandes
                    Text('Évolution des commandes',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: _buildLineChart(
                        charts['orders_evolution'] as List,
                        'Commandes',
                        Colors.blue,
                      ),
                    ),
                    const Divider(height: 24),
                    
                    // Évolution du chiffre d'affaires
                    Text('Évolution du chiffre d\'affaires',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: _buildLineChart(
                        charts['revenue_evolution'] as List,
                        'Chiffre d\'affaires (DA)',
                        Colors.green,
                      ),
                    ),
                    const Divider(height: 24),
                    
                    // Répartition des utilisateurs par rôle
                    Text('Utilisateurs par rôle',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: _buildPieChart(
                        charts['users_by_role'] as List,
                        'role',
                        'count',
                      ),
                    ),
                    const Divider(height: 24),
                    
                    // Répartition des commandes par statut
                    Text('Commandes par statut',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: _buildPieChart(
                        charts['orders_by_status'] as List,
                        'status',
                        'count',
                      ),
                    ),
                    const Divider(height: 24),
                    
                    // Top 5 organisations
                    Text('Top 5 organisations par CA',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(charts['top_orgs_by_revenue'] as List).map((org) => ListTile(
                          leading: CircleAvatar(
                            child: Text('${(charts['top_orgs_by_revenue'] as List).indexOf(org) + 1}'),
                          ),
                          title: Text(org['name']),
                          trailing: Text('${org['revenue']} DA',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          dense: true,
                        )),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Widget _buildLineChart(List<dynamic> data, String label, Color color) {
    if (data.isEmpty) {
      return const Center(child: Text('Aucune donnée'));
    }

    // Préparer les données pour le graphique
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final value = item['count'] != null 
          ? double.parse(item['count'].toString())
          : double.parse(item['amount'].toString());
      spots.add(FlSpot(i.toDouble(), value));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  final date = data[value.toInt()]['date'].toString();
                  return Text(
                    date.substring(8, 10), // Jour uniquement
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.2),
            ),
          ),
        ],
        minY: 0,
      ),
    );
  }

  Widget _buildPieChart(List<dynamic> data, String labelKey, String valueKey) {
    if (data.isEmpty) {
      return const Center(child: Text('Aucune donnée'));
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    final sections = <PieChartSectionData>[];
    final total = data.fold<double>(
      0,
      (sum, item) => sum + double.parse(item[valueKey].toString()),
    );

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final value = double.parse(item[valueKey].toString());
      final percentage = (value / total * 100).toStringAsFixed(1);
      
      sections.add(
        PieChartSectionData(
          value: value,
          title: '$percentage%',
          color: colors[i % colors.length],
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: data.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  color: colors[index % colors.length],
                ),
                const SizedBox(width: 4),
                Text(
                  '${item[labelKey]}: ${item[valueKey]}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================
  // PHASE 3 - GESTION AVANCÉE DES ORGANISATIONS
  // ============================================

  void _showDuplicateOrgDialog(Map<String, dynamic> org) {
    final nameController = TextEditingController();
    bool copyUsers = false;
    bool copyProducts = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Dupliquer "${org['name']}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la nouvelle organisation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Copier les produits'),
                value: copyProducts,
                onChanged: (value) {
                  setState(() => copyProducts = value ?? false);
                },
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Copier les utilisateurs'),
                subtitle: const Text('(désactivés par défaut)'),
                value: copyUsers,
                onChanged: (value) {
                  setState(() => copyUsers = value ?? false);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nom requis')),
                  );
                  return;
                }

                Navigator.pop(context);
                await _duplicateOrganization(
                  org['id'],
                  nameController.text,
                  copyUsers,
                  copyProducts,
                );
              },
              child: const Text('Dupliquer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _duplicateOrganization(
    String orgId,
    String newName,
    bool copyUsers,
    bool copyProducts,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/organizations/$orgId/duplicate'),
        headers: headers,
        body: json.encode({
          'newName': newName,
          'copyUsers': copyUsers,
          'copyProducts': copyProducts,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organisation dupliquée avec succès')),
        );
        _loadOrganizations();
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${error['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _archiveOrganization(String orgId, String orgName) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archiver "$orgName"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cette action va désactiver l\'organisation et tous ses utilisateurs.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Raison (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/super-admin/organizations/$orgId/archive'),
          headers: headers,
          body: json.encode({'reason': reasonController.text}),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Organisation archivée')),
          );
          _loadOrganizations();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _restoreOrganization(String orgId, String orgName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restaurer "$orgName"'),
        content: const Text('Cette action va réactiver l\'organisation et ses administrateurs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/super-admin/organizations/$orgId/restore'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Organisation restaurée')),
          );
          _loadOrganizations();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _showArchivedOrganizations() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/organizations/archived'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final archived = data['data'] as List<dynamic>;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Organisations archivées'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: archived.isEmpty
                  ? const Center(child: Text('Aucune organisation archivée'))
                  : ListView.builder(
                      itemCount: archived.length,
                      itemBuilder: (context, index) {
                        final org = archived[index];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.archive, color: Colors.white),
                            ),
                            title: Text(org['name']),
                            subtitle: Text(
                              'Type: ${org['type']}\n'
                              'Utilisateurs: ${org['users_count']} • '
                              'Commandes: ${org['orders_count']}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.unarchive, color: Colors.green),
                              onPressed: () {
                                Navigator.pop(context);
                                _restoreOrganization(org['id'], org['name']);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _checkSystemHealth() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/health'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final health = data['data'];
        final status = health['status'];
        final checks = health['checks'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  status == 'healthy' ? Icons.check_circle : Icons.warning,
                  color: status == 'healthy' ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text('Santé du système: $status'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHealthCheck('Base de données', checks['database']),
                    _buildHealthCheck('Organisations actives', checks['active_organizations']),
                    _buildHealthCheck('Sessions actives', checks['active_sessions']),
                    _buildHealthCheck('Erreurs récentes', checks['recent_errors']),
                    _buildHealthCheck('Espace disque', checks['disk_space']),
                    const Divider(height: 24),
                    Text('Dernière vérification: ${health['timestamp']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Widget _buildHealthCheck(String label, Map<String, dynamic> check) {
    final status = check['status'];
    final color = status == 'ok' ? Colors.green : 
                  status == 'warning' ? Colors.orange : Colors.red;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            status == 'ok' ? Icons.check_circle : Icons.warning,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (check['count'] != null)
                  Text('${check['count']}', style: const TextStyle(fontSize: 12)),
                if (check['message'] != null)
                  Text(check['message'], style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // PHASE 4 - MONITORING ET PERFORMANCE
  // ============================================

  Widget _buildMonitoring() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Boutons d'action
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showPerformanceMetrics,
                icon: const Icon(Icons.speed),
                label: const Text('Performance'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showRealtimeMetrics,
                icon: const Icon(Icons.update),
                label: const Text('Temps réel'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showTrendsAnalysis,
                icon: const Icon(Icons.trending_up),
                label: const Text('Tendances'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showErrorsAnalysis,
                icon: const Icon(Icons.bug_report),
                label: const Text('Erreurs'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _showRecommendations,
          icon: const Icon(Icons.lightbulb),
          label: const Text('Recommandations'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const Divider(height: 32),
        
        // Informations rapides
        const Text('Monitoring en temps réel',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Utilisez les boutons ci-dessus pour accéder aux différentes métriques'),
                SizedBox(height: 8),
                Text('• Performance: Temps de réponse, requêtes lentes',
                    style: TextStyle(fontSize: 12)),
                Text('• Temps réel: Activité des 5 dernières minutes',
                    style: TextStyle(fontSize: 12)),
                Text('• Tendances: Analyse et prédictions',
                    style: TextStyle(fontSize: 12)),
                Text('• Erreurs: Analyse des erreurs système',
                    style: TextStyle(fontSize: 12)),
                Text('• Recommandations: Suggestions d\'amélioration',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPerformanceMetrics() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/metrics/performance?hours=24'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final metrics = data['data'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Métriques de performance (24h)'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Base de données
                    Text('Base de données',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Taille: ${metrics['database']['size_mb']} MB'),
                    Text('Connexions actives: ${metrics['database']['active_connections']}'),
                    Text('Connexions totales: ${metrics['database']['total_connections']}'),
                    const Divider(height: 24),
                    
                    // Top actions
                    Text('Actions les plus fréquentes',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(metrics['response_times'] as List).take(5).map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${item['action']}: ${item['request_count']} requêtes',
                            style: const TextStyle(fontSize: 12),
                          ),
                        )),
                    const Divider(height: 24),
                    
                    // Requêtes lentes
                    Text('Requêtes les plus lentes',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(metrics['slowest_queries'] as List).take(5).map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${item['action']}: ${double.parse(item['response_time'].toString()).toStringAsFixed(2)}s',
                            style: const TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        )),
                    const Divider(height: 24),
                    
                    // Organisations actives
                    Text('Organisations les plus actives',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(metrics['top_active_orgs'] as List).map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${item['name']}: ${item['activity_count']} actions',
                            style: const TextStyle(fontSize: 12),
                          ),
                        )),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _showRealtimeMetrics() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/metrics/realtime'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final metrics = data['data'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Métriques en temps réel'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dernière mise à jour: ${metrics['timestamp']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Divider(height: 24),
                
                _buildMetricRow('Actions totales (5 min)', 
                    metrics['activity']['total_actions'].toString(), Icons.activity),
                _buildMetricRow('Organisations actives', 
                    metrics['activity']['active_orgs'].toString(), Icons.business),
                _buildMetricRow('Utilisateurs actifs', 
                    metrics['activity']['active_users'].toString(), Icons.people),
                _buildMetricRow('Erreurs', 
                    metrics['activity']['errors'].toString(), Icons.error,
                    color: Colors.red),
                const Divider(height: 16),
                _buildMetricRow('Commandes (1 min)', 
                    metrics['orders']['count'].toString(), Icons.shopping_cart),
                _buildMetricRow('Sessions actives', 
                    metrics['sessions']['count'].toString(), Icons.login),
                _buildMetricRow('Connexions réussies (5 min)', 
                    metrics['logins']['successful'].toString(), Icons.check_circle,
                    color: Colors.green),
                _buildMetricRow('Connexions échouées (5 min)', 
                    metrics['logins']['failed'].toString(), Icons.cancel,
                    color: Colors.red),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showRealtimeMetrics(); // Rafraîchir
                },
                child: const Text('Rafraîchir'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Widget _buildMetricRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, 
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              )),
        ],
      ),
    );
  }

  Future<void> _showTrendsAnalysis() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/analytics/trends?days=30'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final trends = data['data'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Analyse des tendances (30 jours)'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Prédictions
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Prédictions',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Commandes moyennes/jour (semaine prochaine): ${trends['predictions']['avg_daily_orders_next_week']}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Organisations en croissance
                    Text('Organisations en croissance',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(trends['growing_organizations'] as List).map((org) => ListTile(
                          leading: Icon(
                            double.parse(org['growth_rate'].toString()) > 0 
                                ? Icons.trending_up 
                                : Icons.trending_down,
                            color: double.parse(org['growth_rate'].toString()) > 0 
                                ? Colors.green 
                                : Colors.red,
                          ),
                          title: Text(org['name']),
                          subtitle: Text('${org['recent_orders']} commandes (7j)'),
                          trailing: Text('${org['growth_rate']}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: double.parse(org['growth_rate'].toString()) > 0 
                                    ? Colors.green 
                                    : Colors.red,
                              )),
                          dense: true,
                        )),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _showErrorsAnalysis() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/errors/analysis?days=7'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final analysis = data['data'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Analyse des erreurs (7 jours)'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats de résolution
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Statistiques de résolution',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Types d\'erreurs: ${analysis['resolution_stats']['total_error_types']}'),
                            Text('Résolues (>24h): ${analysis['resolution_stats']['resolved_count']}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Erreurs par type
                    Text('Erreurs par type',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(analysis['errors_by_type'] as List).take(10).map((error) => ListTile(
                          leading: const Icon(Icons.error, color: Colors.red),
                          title: Text(error['action'], style: const TextStyle(fontSize: 12)),
                          trailing: Text('${error['count']}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          dense: true,
                        )),
                    const Divider(height: 24),
                    
                    // Erreurs récurrentes
                    Text('Erreurs récurrentes (>5 fois)',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(analysis['recurring_errors'] as List).map((error) => Card(
                          color: Colors.red.shade50,
                          child: ListTile(
                            title: Text(error['action'], style: const TextStyle(fontSize: 12)),
                            subtitle: Text('${error['occurrences']} occurrences'),
                            dense: true,
                          ),
                        )),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _showRecommendations() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/recommendations'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final recommendations = data['data']['recommendations'] as List<dynamic>;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 8),
                Text('Recommandations (${data['data']['total']})'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: recommendations.isEmpty
                  ? const Center(child: Text('Aucune recommandation\nTout fonctionne parfaitement!'))
                  : ListView.builder(
                      itemCount: recommendations.length,
                      itemBuilder: (context, index) {
                        final rec = recommendations[index];
                        final color = rec['priority'] == 'high' ? Colors.red :
                                     rec['priority'] == 'medium' ? Colors.orange :
                                     Colors.blue;
                        
                        return Card(
                          color: color.withOpacity(0.1),
                          child: ExpansionTile(
                            leading: Icon(
                              rec['type'] == 'error' ? Icons.error :
                              rec['type'] == 'warning' ? Icons.warning :
                              Icons.info,
                              color: color,
                            ),
                            title: Text(rec['title']),
                            subtitle: Text('Priorité: ${rec['priority']} • ${rec['category']}'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(rec['description']),
                                    const SizedBox(height: 8),
                                    Text('Action recommandée:',
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(rec['action']),
                                    const SizedBox(height: 8),
                                    Text('Éléments affectés: ${rec['affected_count']}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  // ============================================
  // PHASE 5 - ONGLET RAPPORTS
  // ============================================

  Widget _buildReports() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Rapports prédéfinis',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        // Rapport quotidien
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.today, color: Colors.white),
            ),
            title: const Text('Rapport quotidien'),
            subtitle: const Text('Commandes, CA, nouveaux utilisateurs, erreurs'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: _showDailyReport,
          ),
        ),
        
        // Rapport hebdomadaire
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.date_range, color: Colors.white),
            ),
            title: const Text('Rapport hebdomadaire'),
            subtitle: const Text('Évolution vs semaine précédente, top organisations'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: _showWeeklyReport,
          ),
        ),
        
        // Rapport mensuel
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.calendar_month, color: Colors.white),
            ),
            title: const Text('Rapport mensuel'),
            subtitle: const Text('CA total, croissance, statistiques détaillées'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: _showMonthlyReport,
          ),
        ),
        
        const Divider(height: 32),
        
        const Text('Historique des rapports',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        ElevatedButton.icon(
          onPressed: _showReportsHistory,
          icon: const Icon(Icons.history),
          label: const Text('Voir l\'historique'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  Future<void> _showDailyReport() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) return;

    try {
      final headers = await _getHeaders();
      final dateStr = selectedDate.toIso8601String().split('T')[0];
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/reports/daily?date=$dateStr'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final report = data['data'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Rapport quotidien - ${report['date']}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Commandes
                    _buildReportSection('Commandes', [
                      'Total: ${report['orders']['total_orders']}',
                      'En attente: ${report['orders']['pending']}',
                      'Livrées: ${report['orders']['delivered']}',
                      'Annulées: ${report['orders']['cancelled']}',
                      'CA: ${report['orders']['total_revenue']} DA',
                      'Panier moyen: ${double.parse(report['orders']['avg_order_value'].toString()).toStringAsFixed(2)} DA',
                    ]),
                    
                    // Nouveaux utilisateurs
                    _buildReportSection('Nouveaux utilisateurs', [
                      'Total: ${report['new_users']['total']}',
                      'Clients: ${report['new_users']['customers']}',
                      'Livreurs: ${report['new_users']['deliverers']}',
                      'Admins: ${report['new_users']['admins']}',
                    ]),
                    
                    // Erreurs
                    _buildReportSection('Erreurs', [
                      'Total: ${report['errors']['total']}',
                      if ((report['errors']['by_type'] as List).isNotEmpty)
                        ...(report['errors']['by_type'] as List).take(5).map((e) => 
                          '${e['action']}: ${e['count']}'),
                    ]),
                    
                    // Top organisations
                    if ((report['top_organizations'] as List).isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text('Top organisations',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(report['top_organizations'] as List).take(5).map((org) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('${org['name']}: ${org['orders_count']} cmd, ${org['revenue']} DA',
                              style: const TextStyle(fontSize: 12)),
                        )),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Export PDF/CSV
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export disponible prochainement')),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Exporter'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _showWeeklyReport() async {
    try {
      final headers = await _getHeaders();
      final weekStart = DateTime.now().subtract(const Duration(days: 7))
          .toIso8601String().split('T')[0];
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/reports/weekly?week_start=$weekStart'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final report = data['data'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Rapport hebdomadaire\n${report['period']['start']} → ${report['period']['end']}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Croissance
                    Card(
                      color: double.parse(report['growth']['orders'].toString()) >= 0 
                          ? Colors.green.shade50 
                          : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Croissance vs semaine précédente',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Commandes: ${report['growth']['orders']}%'),
                            Text('CA: ${report['growth']['revenue']}%'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Stats semaine actuelle
                    _buildReportSection('Cette semaine', [
                      'Commandes: ${report['current_week']['total_orders']}',
                      'CA: ${report['current_week']['total_revenue']} DA',
                      'Nouveaux utilisateurs: ${report['current_week']['new_users']}',
                      'Organisations actives: ${report['current_week']['active_orgs']}',
                    ]),
                    
                    // Top organisations
                    if ((report['top_organizations'] as List).isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text('Top organisations',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(report['top_organizations'] as List).take(5).map((org) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('${org['name']}: ${org['revenue']} DA',
                              style: const TextStyle(fontSize: 12)),
                        )),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _showMonthlyReport() async {
    try {
      final headers = await _getHeaders();
      final now = DateTime.now();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/reports/monthly?year=${now.year}&month=${now.month}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final report = data['data'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Rapport mensuel\n${report['period']['month_name']} ${report['period']['year']}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Croissance
                    Card(
                      color: double.parse(report['growth']['orders'].toString()) >= 0 
                          ? Colors.green.shade50 
                          : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Croissance vs mois précédent',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Commandes: ${report['growth']['orders']}%'),
                            Text('CA: ${report['growth']['revenue']}%'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Stats du mois
                    _buildReportSection('Ce mois', [
                      'Commandes: ${report['current_month']['total_orders']}',
                      'CA: ${report['current_month']['total_revenue']} DA',
                      'Panier moyen: ${double.parse(report['current_month']['avg_order_value'].toString()).toStringAsFixed(2)} DA',
                      'Clients uniques: ${report['current_month']['unique_customers']}',
                      'Nouveaux utilisateurs: ${report['current_month']['new_users']}',
                      'Organisations actives: ${report['current_month']['active_orgs']}',
                    ]),
                    
                    // Top organisations
                    if ((report['top_organizations'] as List).isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text('Top organisations',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(report['top_organizations'] as List).take(5).map((org) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('${org['name']}: ${org['revenue']} DA (${org['orders_count']} cmd)',
                              style: const TextStyle(fontSize: 12)),
                        )),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Widget _buildReportSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item', style: const TextStyle(fontSize: 12)),
            )),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _showReportsHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/reports/history?limit=50'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final reports = data['data'] as List<dynamic>;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Historique des rapports'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: reports.isEmpty
                  ? const Center(child: Text('Aucun rapport généré'))
                  : ListView.builder(
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        return ListTile(
                          leading: Icon(
                            report['type'] == 'daily' ? Icons.today :
                            report['type'] == 'weekly' ? Icons.date_range :
                            Icons.calendar_month,
                          ),
                          title: Text('Rapport ${report['type']}'),
                          subtitle: Text('Généré le ${report['generated_at']?.substring(0, 19) ?? 'N/A'}'),
                          trailing: Text(report['format']),
                          dense: true,
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  // ============================================
  // PHASE 6 - ONGLET PARAMÈTRES
  // ============================================

  Widget _buildSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Paramètres système',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        // Sécurité
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.security, color: Colors.blue),
            title: const Text('Sécurité'),
            children: [
              ListTile(
                title: const Text('Durée de session'),
                subtitle: const Text('24 heures par défaut'),
                trailing: const Icon(Icons.edit),
                onTap: () => _editSetting('security', 'session_duration'),
              ),
              ListTile(
                title: const Text('Tentatives de connexion max'),
                subtitle: const Text('5 tentatives par défaut'),
                trailing: const Icon(Icons.edit),
                onTap: () => _editSetting('security', 'max_login_attempts'),
              ),
              ListTile(
                title: const Text('2FA obligatoire'),
                subtitle: const Text('Désactivé par défaut'),
                trailing: const Icon(Icons.edit),
                onTap: () => _editSetting('security', 'require_2fa'),
              ),
            ],
          ),
        ),
        
        // Notifications
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.notifications, color: Colors.orange),
            title: const Text('Notifications'),
            children: [
              ListTile(
                title: const Text('Alertes par email'),
                subtitle: const Text('Activé par défaut'),
                trailing: const Icon(Icons.edit),
                onTap: () => _editSetting('notifications', 'email_alerts'),
              ),
              ListTile(
                title: const Text('Seuils d\'alerte'),
                subtitle: const Text('Configurer les seuils'),
                trailing: const Icon(Icons.edit),
                onTap: () => _editSetting('notifications', 'alert_thresholds'),
              ),
            ],
          ),
        ),
        
        // Maintenance
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.build, color: Colors.red),
            title: const Text('Maintenance'),
            children: [
              ListTile(
                title: const Text('Mode maintenance'),
                subtitle: const Text('Activer/Désactiver'),
                trailing: const Icon(Icons.toggle_off),
                onTap: _toggleMaintenanceMode,
              ),
            ],
          ),
        ),
        
        // Backup
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.backup, color: Colors.green),
            title: const Text('Backup'),
            children: [
              ListTile(
                title: const Text('Backup automatique'),
                subtitle: const Text('Quotidien, conservation 30 jours'),
                trailing: const Icon(Icons.edit),
                onTap: () => _editSetting('backup', 'auto_backup'),
              ),
            ],
          ),
        ),
        
        const Divider(height: 32),
        
        // Actions de maintenance
        const Text('Actions de maintenance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        ElevatedButton.icon(
          onPressed: _clearCache,
          icon: const Icon(Icons.cleaning_services),
          label: const Text('Vider le cache'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 8),
        
        ElevatedButton.icon(
          onPressed: _cleanupSessions,
          icon: const Icon(Icons.delete_sweep),
          label: const Text('Nettoyer les sessions expirées'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 8),
        
        ElevatedButton.icon(
          onPressed: _cleanupLogs,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Nettoyer les anciens logs'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        
        const Divider(height: 32),
        
        // Informations système
        const Text('Informations système',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        ElevatedButton.icon(
          onPressed: _showSystemInfo,
          icon: const Icon(Icons.info),
          label: const Text('Voir les informations système'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 8),
        
        ElevatedButton.icon(
          onPressed: _showDatabaseStats,
          icon: const Icon(Icons.storage),
          label: const Text('Statistiques base de données'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  Future<void> _editSetting(String category, String key) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Édition des paramètres disponible prochainement')),
    );
  }

  Future<void> _toggleMaintenanceMode() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mode maintenance'),
        content: const Text('Voulez-vous activer le mode maintenance?\n\nCela empêchera les utilisateurs de se connecter.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Activer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/super-admin/maintenance/toggle'),
          headers: headers,
          body: json.encode({
            'enabled': true,
            'message': 'Maintenance en cours. Nous serons de retour bientôt.',
          }),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mode maintenance activé')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le cache'),
        content: const Text('Voulez-vous vider tout le cache Redis?\n\nCela peut temporairement ralentir l\'application.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/super-admin/cache/clear'),
          headers: headers,
          body: json.encode({'type': 'all'}),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _cleanupSessions() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/cleanup/sessions'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _cleanupLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nettoyer les logs'),
        content: const Text('Supprimer tous les logs de plus de 90 jours?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/super-admin/cleanup/logs'),
          headers: headers,
          body: json.encode({'older_than_days': 90}),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _showSystemInfo() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/system/info'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final info = data['data'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Informations système'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInfoSection('Node.js', [
                      'Version: ${info['node_version']}',
                      'Plateforme: ${info['platform']}',
                      'Uptime: ${(info['uptime'] / 3600).toStringAsFixed(2)}h',
                    ]),
                    _buildInfoSection('Mémoire', [
                      'Total: ${info['memory']['total']} MB',
                      'Utilisée: ${info['memory']['used']} MB',
                      'Externe: ${info['memory']['external']} MB',
                    ]),
                    _buildInfoSection('Base de données', [
                      'Taille: ${info['database']['size_mb']} MB',
                      'Connexions actives: ${info['database']['active_connections']}',
                      'Connexions totales: ${info['database']['total_connections']}',
                      'Version: ${info['database']['version']}',
                    ]),
                    _buildInfoSection('Redis', [
                      'Statut: ${info['redis']['status']}',
                      if (info['redis']['version'] != null)
                        'Version: ${info['redis']['version']}',
                    ]),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _showDatabaseStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/database/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final stats = data['data'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Statistiques base de données'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Taille des tables',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...(stats['table_sizes'] as List).take(10).map((table) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${table['tablename']}: ${table['size']}',
                            style: const TextStyle(fontSize: 12)),
                      )),
                    const Divider(height: 24),
                    
                    const Text('Nombre de lignes',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...(stats['row_counts'] as List).take(10).map((table) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${table['tablename']}: ${table['row_count']} lignes',
                            style: const TextStyle(fontSize: 12)),
                      )),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Widget _buildInfoSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item', style: const TextStyle(fontSize: 12)),
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}
