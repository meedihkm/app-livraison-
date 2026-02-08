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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await SecureStorage.getAccessToken();
    // Super admin key depuis .env
    const superAdminKey = String.fromEnvironment('SUPER_ADMIN_KEY', defaultValue: '');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'x-super-admin-key': superAdminKey,
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Organisations'),
            Tab(text: 'Sessions'),
            Tab(text: 'Sécurité'),
            Tab(text: 'Logs'),
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
              ],
            ),
    );
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
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
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
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showOrgOptions(org),
              ),
            ),
          );
        },
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

  void _showOrgOptions(Map<String, dynamic> org) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Modifier'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implémenter modification
            },
          ),
          ListTile(
            leading: Icon(org['active'] ? Icons.block : Icons.check_circle),
            title: Text(org['active'] ? 'Désactiver' : 'Activer'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implémenter toggle status
            },
          ),
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: const Text('Voir croissance'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implémenter graphiques
            },
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
