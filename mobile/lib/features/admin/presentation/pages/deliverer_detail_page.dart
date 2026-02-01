import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';

class DelivererDetailPage extends StatefulWidget {
  final Map<String, dynamic> deliverer;
  const DelivererDetailPage({required this.deliverer});

  @override
  _DelivererDetailPageState createState() => _DelivererDetailPageState();
}

class _DelivererDetailPageState extends State<DelivererDetailPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _deliveries = [];
  bool _isLoading = true;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notesController.text = (widget.deliverer['notes'] as String?) ?? '';
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    try {
      final response = await _apiService.getDeliveries(delivererId: widget.deliverer['id'] as String, limit: 100);
      if (response['success'] == true) {
        final allDeliveries = response['data'] as List;
        setState(() {
          _deliveries = allDeliveries; // API already filtered by delivererId
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int get _totalDeliveries => _deliveries.length;
  
  int get _completedDeliveries => _deliveries.where((d) => d['status'] == 'delivered').length;
  
  int get _pendingDeliveries => _deliveries.where((d) => d['status'] == 'pending' || d['status'] == 'in_progress').length;

  double get _totalAmount {
    return _deliveries.fold(0.0, (sum, d) {
      final orders = d['orders'] as List? ?? [];
      double deliveryTotal = 0;
      for (var o in orders) {
        deliveryTotal += _parseDouble(o['total']);
      }
      return sum + deliveryTotal;
    });
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final deliverer = widget.deliverer;
    final isBlocked = deliverer['active'] == false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Fiche livreur'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isBlocked ? Icons.lock : Icons.lock_open),
            tooltip: isBlocked ? 'Débloquer' : 'Bloquer',
            onPressed: () => _toggleBlock(deliverer),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header livreur
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isBlocked 
                          ? [Colors.red.shade400, Colors.red.shade600] 
                          : [Colors.orange.shade400, Colors.orange.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: Icon(Icons.delivery_dining, color: Colors.white, size: 32),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (deliverer['name'] as String?) ?? 'Livreur',
                                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (isBlocked)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                      child: Text('BLOQUÉ', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              if (deliverer['email'] != null)
                                Text(deliverer['email'] as String, style: TextStyle(color: Colors.white70)),
                              if (deliverer['phone'] != null && deliverer['phone'].toString().isNotEmpty)
                                Text(deliverer['phone'] as String, style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Stats
                  Row(
                    children: [
                      _buildStatCard('Livraisons', '$_totalDeliveries', Icons.local_shipping, Colors.blue),
                      SizedBox(width: 12),
                      _buildStatCard('Terminées', '$_completedDeliveries', Icons.check_circle, Colors.green),
                      SizedBox(width: 12),
                      _buildStatCard('En cours', '$_pendingDeliveries', Icons.hourglass_empty, Colors.orange),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatCard('Montant total', '${_totalAmount.toStringAsFixed(0)} DA', Icons.attach_money, Colors.purple),
                      SizedBox(width: 12),
                      _buildStatCard('Taux réussite', _totalDeliveries > 0 ? '${((_completedDeliveries / _totalDeliveries) * 100).toStringAsFixed(0)}%' : '0%', Icons.trending_up, Colors.teal),
                      SizedBox(width: 12),
                      Expanded(child: SizedBox()),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Notes
                  Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Ajouter des notes sur ce livreur...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Historique livraisons
                  Text('Historique livraisons', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 12),
                  if (_deliveries.isEmpty)
                    Center(child: Text('Aucune livraison', style: TextStyle(color: Colors.grey)))
                  else
                    ..._deliveries.take(15).map((delivery) => _buildDeliveryCard(delivery as Map<String, dynamic>)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
    final date = DateTime.tryParse((delivery['createdAt'] as String?) ?? '');
    final status = (delivery['status'] as String?) ?? 'pending';
    final orders = delivery['orders'] as List? ?? [];
    final orderCount = orders.length;

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
          child: Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 20),
        ),
        title: Text('$orderCount commande${orderCount > 1 ? 's' : ''}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date != null ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}' : ''),
            Text(_getStatusText(status), style: TextStyle(color: _getStatusColor(status), fontSize: 12)),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'pending': return Icons.hourglass_empty;
      case 'in_progress': return Icons.directions_bike;
      case 'delivered': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.local_shipping;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'in_progress': return 'En cours';
      case 'delivered': return 'Livrée';
      case 'cancelled': return 'Annulée';
      default: return status ?? '';
    }
  }

  Future<void> _toggleBlock(Map<String, dynamic> deliverer) async {
    final isBlocked = deliverer['active'] == false;
    final action = isBlocked ? 'débloquer' : 'bloquer';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${isBlocked ? 'Débloquer' : 'Bloquer'} ce livreur?'),
        content: Text(isBlocked 
          ? 'Ce livreur pourra à nouveau effectuer des livraisons.'
          : 'Ce livreur ne pourra plus effectuer de livraisons.'),
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
        await _apiService.toggleUser(deliverer['id'] as String);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Livreur ${isBlocked ? 'débloqué' : 'bloqué'}'), backgroundColor: isBlocked ? Colors.green : Colors.orange),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }
}
