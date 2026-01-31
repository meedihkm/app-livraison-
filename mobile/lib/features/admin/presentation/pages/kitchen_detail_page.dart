import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/api_service.dart';

class KitchenDetailPage extends StatefulWidget {
  final Map<String, dynamic> kitchen;
  final ApiService? apiService;

  const KitchenDetailPage({
    required this.kitchen,
    this.apiService,
    Key? key,
  }) : super(key: key);

  @override
  _KitchenDetailPageState createState() => _KitchenDetailPageState();
}

class _KitchenDetailPageState extends State<KitchenDetailPage> {
  late final ApiService _apiService;
  int _totalOrdersProcessed = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Charger uniquement le nombre de commandes traitées
      final result = await _apiService.getOrders(limit: 1000);
      final orders = (result['data'] as List?) ?? [];

      setState(() {
        _totalOrdersProcessed = orders.length;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading kitchen data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _callKitchen() async {
    final phone = widget.kitchen['phone'];
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _toggleBlock() async {
    final isBlocked = widget.kitchen['active'] == false;
    final action = isBlocked ? 'débloquer' : 'bloquer';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${isBlocked ? 'Débloquer' : 'Bloquer'} cet atelier?'),
        content: Text(isBlocked
            ? 'Cet atelier pourra à nouveau traiter des commandes.'
            : 'Cet atelier ne pourra plus traiter de commandes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isBlocked ? Colors.green : Colors.red),
            child: Text(action.toUpperCase(), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.toggleUser(widget.kitchen['id']);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Atelier ${isBlocked ? 'débloqué' : 'bloqué'}'),
              backgroundColor: isBlocked ? Colors.green : Colors.orange),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = widget.kitchen;
    final isBlocked = kitchen['active'] == false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Fiche atelier'),
        backgroundColor: Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          if (kitchen['phone'] != null)
            IconButton(icon: Icon(Icons.phone), onPressed: _callKitchen, tooltip: 'Appeler'),
          IconButton(
            icon: Icon(isBlocked ? Icons.lock : Icons.lock_open),
            tooltip: isBlocked ? 'Débloquer' : 'Bloquer',
            onPressed: _toggleBlock,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Color(0xFF2E7D32),
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Header
                    _buildHeader(kitchen, isBlocked),

                    // Infos détaillées
                    _buildInfoSection(kitchen),

                    // Stats
                    _buildStatsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> kitchen, bool isBlocked) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBlocked ? [Colors.red.shade400, Colors.red.shade600] : [Color(0xFF2E7D32), Color(0xFF1B5E20)],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(Icons.restaurant, color: Colors.white, size: 40),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                kitchen['name'] ?? 'Atelier',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (isBlocked) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Text('BLOQUÉ', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          if (kitchen['email'] != null)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(kitchen['email'], style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> kitchen) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 16),

          // Téléphone
          _buildInfoRow(Icons.phone, 'Téléphone', kitchen['phone'] ?? 'Non renseigné',
              onTap: kitchen['phone'] != null ? _callKitchen : null),
          Divider(height: 24),

          // Email
          _buildInfoRow(Icons.email, 'Email', kitchen['email'] ?? 'Non renseigné'),
          Divider(height: 24),

          // Date d'inscription
          _buildInfoRow(
              Icons.calendar_today, 'Membre depuis', _formatDate(kitchen['createdAt'] ?? kitchen['created_at'])),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF2E7D32), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu, size: 48, color: Color(0xFF2E7D32)),
          SizedBox(height: 12),
          Text(
            '$_totalOrdersProcessed',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
          ),
          Text(
            'Commandes traitées',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return 'N/A';
    final months = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${months[date.month]} ${date.year}';
  }
}
