import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
    _tabController = TabController(length: 7, vsync: this);
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
          // Bouton statistiques avancées
          ElevatedButton.icon(
            onPressed: _showAdvancedStats,
            icon: const Icon(Icons.analytics),
            label: const Text('Statistiques avancées'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
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
          ElevatedButton.icon(
            onPressed: _triggerBackup,
            icon: const Icon(Icons.backup),
            label: const Text('Créer un backup'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _checkSystemHealth,
            icon: const Icon(Icons.health_and_safety),
            label: const Text('Santé du système'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
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
}
