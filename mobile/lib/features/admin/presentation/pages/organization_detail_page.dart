import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/secure_storage.dart';

class OrganizationDetailPage extends StatefulWidget {
  final String organizationId;
  final String organizationName;

  const OrganizationDetailPage({
    Key? key,
    required this.organizationId,
    required this.organizationName,
  }) : super(key: key);

  @override
  State<OrganizationDetailPage> createState() => _OrganizationDetailPageState();
}

class _OrganizationDetailPageState extends State<OrganizationDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _details;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDetails();
  }

  Future<Map<String, String>> _getHeaders() async {
    final storage = SecureStorage();
    final token = await storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/organizations/${widget.organizationId}/details'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _details = data['data']);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.organizationName),
        actions: [
          // Bouton export CSV utilisateurs
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showExportMenu,
            tooltip: 'Exporter',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Vue d\'ensemble'),
            Tab(text: 'Utilisateurs'),
            Tab(text: 'Croissance'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _details == null
              ? const Center(child: Text('Aucune donnée'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverview(),
                    _buildUsers(),
                    _buildGrowth(),
                  ],
                ),
    );
  }

  Widget _buildOverview() {
    final general = _details!['general'];
    final stats = _details!['stats'];
    final topCustomers = _details!['top_customers'] as List<dynamic>;

    return RefreshIndicator(
      onRefresh: _loadDetails,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Informations générales
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Informations générales',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _buildInfoRow('Type', general['type']),
                  _buildInfoRow('Statut', general['active'] ? 'Active' : 'Inactive'),
                  _buildInfoRow('Mode cuisine', general['kitchen_mode'] ? 'Activé' : 'Désactivé'),
                  _buildInfoRow('Date de création', general['created_at']?.substring(0, 10) ?? 'N/A'),
                  _buildInfoRow('Dernière activité', general['last_activity']?.substring(0, 10) ?? 'Jamais'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Statistiques utilisateurs
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Utilisateurs', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _buildStatRow('Total', stats['total_users'].toString(), Icons.people),
                  _buildStatRow('Clients', stats['customers'].toString(), Icons.person),
                  _buildStatRow('Livreurs', stats['deliverers'].toString(), Icons.delivery_dining),
                  _buildStatRow('Admins', stats['admins'].toString(), Icons.admin_panel_settings),
                  _buildStatRow('Cuisine', stats['kitchen'].toString(), Icons.restaurant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Statistiques commandes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Commandes', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _buildStatRow('Total', stats['total_orders'].toString(), Icons.shopping_cart),
                  _buildStatRow('En attente', stats['orders_pending'].toString(), Icons.pending),
                  _buildStatRow('Livrées', stats['orders_delivered'].toString(), Icons.check_circle),
                  _buildStatRow('Annulées', stats['orders_cancelled'].toString(), Icons.cancel),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Statistiques financières
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chiffre d\'affaires', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _buildStatRow('Total', '${stats['total_revenue']} DA', Icons.attach_money),
                  _buildStatRow('Aujourd\'hui', '${stats['revenue_today']} DA', Icons.today),
                  _buildStatRow('Ce mois', '${stats['revenue_month']} DA', Icons.calendar_month),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Top 10 clients
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top 10 clients', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  if (topCustomers.isEmpty)
                    const Text('Aucun client')
                  else
                    ...topCustomers.map((customer) => ListTile(
                          leading: CircleAvatar(
                            child: Text('${topCustomers.indexOf(customer) + 1}'),
                          ),
                          title: Text(customer['name']),
                          subtitle: Text(customer['email']),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${customer['total_spent']} DA',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${customer['order_count']} commandes',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsers() {
    return FutureBuilder(
      future: _loadUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final users = snapshot.data as List<dynamic>? ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('Aucun utilisateur'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: user['active'] ? Colors.green : Colors.grey,
                  child: Text(user['role'][0].toUpperCase()),
                ),
                title: Text(user['name']),
                subtitle: Text(
                  '${user['email']}\n'
                  'Rôle: ${user['role']} • '
                  'Commandes: ${user['order_count']} • '
                  'Chiffre d\'affaires: ${user['total_revenue']} DA',
                ),
                isThreeLine: true,
                trailing: Text(
                  user['active'] ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    color: user['active'] ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGrowth() {
    final growth = _details!['growth'];
    final ordersData = growth['orders'] as List<dynamic>;
    final revenueData = growth['revenue'] as List<dynamic>;
    final usersData = growth['users'] as List<dynamic>;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Commandes (30 derniers jours)',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (ordersData.isEmpty)
                  const Text('Aucune donnée')
                else
                  ...ordersData.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item['date']?.substring(0, 10) ?? 'N/A'),
                            Text('${item['count']} commandes',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chiffre d\'affaires (30 derniers jours)',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (revenueData.isEmpty)
                  const Text('Aucune donnée')
                else
                  ...revenueData.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item['date']?.substring(0, 10) ?? 'N/A'),
                            Text('${item['amount']} DA',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nouveaux utilisateurs (30 derniers jours)',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (usersData.isEmpty)
                  const Text('Aucune donnée')
                else
                  ...usersData.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item['date']?.substring(0, 10) ?? 'N/A'),
                            Text('${item['count']} utilisateurs',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<List<dynamic>> _loadUsers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/super-admin/organizations/${widget.organizationId}/users/detailed'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      }
    } catch (e) {
      // Ignore
    }
    return [];
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================
  // EXPORT DE DONNÉES
  // ============================================

  void _showExportMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exporter les données'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Utilisateurs (CSV)'),
              subtitle: const Text('Liste complète avec statistiques'),
              onTap: () {
                Navigator.pop(context);
                _exportUsersCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Statistiques (CSV)'),
              subtitle: const Text('Évolution sur 30 jours'),
              onTap: () {
                Navigator.pop(context);
                _exportStatsCSV();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportUsersCSV() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConstants.baseUrl}/super-admin/organizations/${widget.organizationId}/export/csv';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export en cours...\nURL: $url'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _exportStatsCSV() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConstants.baseUrl}/super-admin/organizations/${widget.organizationId}/export/stats-csv?days=30';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export en cours...\nURL: $url'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
}
