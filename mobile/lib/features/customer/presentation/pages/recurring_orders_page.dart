import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/models/recurring_order_model.dart';
import '../widgets/recurring_order_form.dart';

class RecurringOrdersPage extends StatefulWidget {
  const RecurringOrdersPage({Key? key}) : super(key: key);

  @override
  _RecurringOrdersPageState createState() => _RecurringOrdersPageState();
}

class _RecurringOrdersPageState extends State<RecurringOrdersPage> {
  final ApiService _apiService = ApiService();
  List<RecurringOrder> _recurringOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecurringOrders();
  }

  Future<void> _loadRecurringOrders() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getRecurringOrders();
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _recurringOrders = (result['data'] as List)
              .map((e) => RecurringOrder.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showForm({RecurringOrder? order}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecurringOrderForm(
        existingOrder: order,
        onSaved: () {
          Navigator.pop(context);
          _loadRecurringOrders();
        },
      ),
    );
  }

  Future<void> _toggleOrder(RecurringOrder order) async {
    try {
      await _apiService.toggleRecurringOrder(order.id);
      _loadRecurringOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(order.active ? 'Commande mise en pause' : 'Commande réactivée'),
          backgroundColor: order.active ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteOrder(RecurringOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer cette commande récurrente ?'),
        content: Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteRecurringOrder(order.id);
        _loadRecurringOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Commande supprimée'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Commandes Récurrentes'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _recurringOrders.isEmpty
              ? _buildEmptyState()
              : _buildOrdersList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: Icon(Icons.add),
        label: Text('Nouvelle'),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.repeat, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Aucune commande récurrente',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Créez une commande automatique pour gagner du temps',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showForm(),
            icon: Icon(Icons.add),
            label: Text('Créer ma première récurrence'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return RefreshIndicator(
      onRefresh: _loadRecurringOrders,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _recurringOrders.length,
        itemBuilder: (context, index) {
          final order = _recurringOrders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(RecurringOrder order) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: order.active ? Colors.deepPurple.shade50 : Colors.grey.shade200,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.repeat,
                  color: order.active ? Colors.deepPurple : Colors.grey,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.name ?? 'Commande récurrente',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        order.frequencyLabel,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: order.active,
                  onChanged: (_) => _toggleOrder(order),
                  activeColor: Colors.deepPurple,
                ),
              ],
            ),
          ),
          
          // Schedule Info
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.scheduleSummary != null) ...[
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(order.scheduleSummary!, style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                  SizedBox(height: 8),
                ],
                if (order.nextGenerationAt != null && order.active) ...[
                  Row(
                    children: [
                      Icon(Icons.event, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Prochaine: ${_formatDate(order.nextGenerationAt!)}',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                ],
                
                // Items summary
                Text(
                  '${order.items.length} produit${order.items.length > 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          
          // Actions
          Divider(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showForm(order: order),
                icon: Icon(Icons.edit),
                label: Text('Modifier'),
              ),
              TextButton.icon(
                onPressed: () => _deleteOrder(order),
                icon: Icon(Icons.delete, color: Colors.red),
                label: Text('Supprimer', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    
    if (diff.inDays == 0) {
      return "Aujourd'hui ${date.hour}h${date.minute.toString().padLeft(2, '0')}";
    } else if (diff.inDays == 1) {
      return "Demain ${date.hour}h${date.minute.toString().padLeft(2, '0')}";
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
