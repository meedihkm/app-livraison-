import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/print_service.dart';
import '../../../../core/models/order_model.dart';

class KitchenDashboard extends StatefulWidget {
  @override
  _KitchenDashboardState createState() => _KitchenDashboardState();
}

class _KitchenDashboardState extends State<KitchenDashboard> {
  final ApiService _apiService = ApiService();
  final PrintService _printService = PrintService();
  List<Order> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final response = await _apiService.getKitchenOrders();
      if (response['success'] == true) {
        setState(() {
          _orders = (response['data'] is List<dynamic> ? response['data'] as List<dynamic> : []).map((json) => Order.fromJson(json as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _startPreparing(Order order) async {
    try {
      await _apiService.updateKitchenOrderStatus(order.id, 'preparing');
      _loadOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Préparation commencée'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _markReady(Order order) async {
    try {
      await _apiService.updateKitchenOrderStatus(order.id, 'ready');
      
      // Proposer d'imprimer l'étiquette
      final shouldPrint = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Commande prête!'),
          content: Text('Voulez-vous imprimer l\'étiquette client?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Non')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Imprimer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      
      if (shouldPrint == true) {
        await _printService.printClientLabel(order);
      }
      
      _loadOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Commande prête!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final validatedOrders = _orders.where((o) => o.status == 'validated').toList();
    final preparingOrders = _orders.where((o) => o.status == 'preparing').toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.kitchen, size: 28),
            SizedBox(width: 10),
            Text('Awid', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Atelier', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return PopupMenuButton<String>(
                icon: Icon(Icons.account_circle),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'name', enabled: false, child: Text('${authProvider.user?['name']}')),
                  PopupMenuItem(value: 'org', enabled: false, child: Text('${authProvider.user?['organization']['name']}')),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(children: [Icon(Icons.logout, size: 20), SizedBox(width: 8), Text('Déconnexion')]),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'logout') authProvider.logout();
                },
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.purple))
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: _orders.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats rapides
                          Row(
                            children: [
                              _buildStatCard('À préparer', '${validatedOrders.length}', Colors.blue, Icons.hourglass_empty),
                              SizedBox(width: 12),
                              _buildStatCard('En cours', '${preparingOrders.length}', Colors.orange, Icons.restaurant),
                            ],
                          ),
                          SizedBox(height: 24),

                          // Commandes à préparer
                          if (validatedOrders.isNotEmpty) ...[
                            _buildSectionHeader('À préparer', Icons.hourglass_empty, Colors.blue, validatedOrders.length),
                            SizedBox(height: 12),
                            ...validatedOrders.map((order) => _buildOrderCard(order, isNew: true)),
                            SizedBox(height: 24),
                          ],

                          // Commandes en préparation
                          if (preparingOrders.isNotEmpty) ...[
                            _buildSectionHeader('En préparation', Icons.restaurant, Colors.orange, preparingOrders.length),
                            SizedBox(height: 12),
                            ...preparingOrders.map((order) => _buildOrderCard(order, isNew: false)),
                          ],
                        ],
                      ),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
          SizedBox(height: 16),
          Text('Aucune commande à préparer', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          SizedBox(height: 8),
          Text('Les nouvelles commandes apparaîtront ici', style: TextStyle(color: Colors.grey[500])),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadOrders,
            icon: Icon(Icons.refresh),
            label: Text('Actualiser'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, int count) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Text('$count', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Order order, {required bool isNew}) {
    final color = isNew ? Colors.blue : Colors.orange;
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  radius: 24,
                  child: Text(
                    (order.cafeteria?.name ?? 'C')[0].toUpperCase(),
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.cafeteria?.name ?? 'Client',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isNew ? 'NOUVEAU' : 'EN COURS',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Articles (sans prix)
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: order.items.map((item) => Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${item.quantity}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.productName,
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),

          // Actions
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                if (isNew)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _startPreparing(order),
                      icon: Icon(Icons.play_arrow),
                      label: Text('COMMENCER'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markReady(order),
                      icon: Icon(Icons.check_circle),
                      label: Text('PRÊT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showOrderDetails(order),
                  icon: Icon(Icons.info_outline),
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.purple,
                    child: Text((order.cafeteria?.name ?? 'C')[0], style: TextStyle(color: Colors.white)),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.cafeteria?.name ?? 'Client', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        if (order.cafeteria?.phone != null)
                          Text(order.cafeteria!.phone!, style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
                ],
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(20),
                children: [
                  Text('Articles à préparer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 12),
                  ...order.items.map((item) => Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text('${item.quantity}x', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: Text(item.productName, style: TextStyle(fontSize: 16))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
