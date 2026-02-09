import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/secure_storage.dart';

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
      Uri.parse('${ApiConstants.baseUrl}/super-admin/failed-logins'),
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
      Uri.parse('${ApiConstants.baseUrl}/super-admin/error-logs?limit=50'),
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
      Uri.parse('${ApiConstants.baseUrl}/super-admin/activity?limit=50'),
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
          _buildStatCard('Organisations', _stats!['totalOrganizations'].toString(), Icons.business, Colors.blue),
          _buildStatCard('Organisations actives', _stats!['activeOrganizations'].toString(), Icons.check_circle, Colors.green),
          _buildStatCard('Utilisateurs', _stats!['totalUsers'].toString(), Icons.people, Colors.orange),
          _buildStatCard('Commandes totales', _stats!['totalOrders'].toString(), Icons.shopping_cart, Colors.purple),
          const Divider(height: 32),
          Text('Aujourd\'hui', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _buildStatCard('Commandes', _stats!['ordersToday'].toString(), Icons.today, Colors.indigo),
          _buildStatCard('CA', '${_stats!['revenueToday']} DA', Icons.attach_money, Colors.teal),
          _buildStatCard('Users actifs (24h)', _stats!['activeUsers24h'].toString(), Icons.person_outline, Colors.cyan),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _triggerBackup,
            icon: const Icon(Icons.backup),
            label: const Text('Créer un backup'),
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
            child: ElevatedButton.icon(
              onPressed: _showCreateOrgDialog,
              icon: const Icon(Icons.add),
              label: const Text('Créer une organisation'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
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
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _failedLogins.length,
        itemBuilder: (context, index) {
          final login = _failedLogins[index];
          return Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: Text(login['email'] ?? 'Inconnu'),
              subtitle: Text('IP: ${login['ip']}\nTentatives: ${login['attempts']}'),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogs() {
    return RefreshIndicator(
      onRefresh: _loadErrorLogs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _errorLogs.length,
        itemBuilder: (context, index) {
          final log = _errorLogs[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline, color: Colors.orange),
              title: Text(log['action']),
              subtitle: Text('${log['organization_name'] ?? 'N/A'}\n${log['created_at']}'),
              isThreeLine: true,
            ),
          );
        },
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
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activity.length,
        itemBuilder: (context, index) {
          final log = _activity[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(_getActionIcon(log['action'])),
              ),
              title: Text(log['action']),
              subtitle: Text(
                '${log['organization_name'] ?? 'N/A'}\n'
                '${log['user_name'] ?? 'Système'} (${log['user_email'] ?? 'N/A'})\n'
                '${log['created_at']}',
              ),
              isThreeLine: true,
            ),
          );
        },
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
}
