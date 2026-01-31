import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/print_service.dart';
import '../../../../core/models/delivery_model.dart';

class DeliveryHistoryPage extends StatefulWidget {
  @override
  _DeliveryHistoryPageState createState() => _DeliveryHistoryPageState();
}

class _DeliveryHistoryPageState extends State<DeliveryHistoryPage> {
  final ApiService _apiService = ApiService();
  final PrintService _printService = PrintService();
  List<Delivery> _deliveries = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, today, week

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getDeliveryHistory();
      if (response['success']) {
        setState(() {
          _deliveries = (response['data'] as List)
              .map((json) => Delivery.fromJson(json))
              .toList();
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

  List<Delivery> get _filteredDeliveries {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(Duration(days: 7));

    switch (_filter) {
      case 'today':
        return _deliveries.where((d) {
          if (d.deliveredAt == null) return false;
          return d.deliveredAt!.isAfter(today);
        }).toList();
      case 'week':
        return _deliveries.where((d) {
          if (d.deliveredAt == null) return false;
          return d.deliveredAt!.isAfter(weekAgo);
        }).toList();
      default:
        return _deliveries;
    }
  }

  void _showPrintOptions(Delivery delivery) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Imprimer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              delivery.order.cafeteria?.name ?? 'Client',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.description, color: Colors.blue),
              ),
              title: Text('Bon de livraison A5'),
              subtitle: Text('Format standard'),
              onTap: () {
                Navigator.pop(context);
                _printService.printDeliverySlip(delivery);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long, color: Colors.orange),
              ),
              title: Text('Ticket thermique'),
              subtitle: Text('Format 80mm'),
              onTap: () {
                Navigator.pop(context);
                _printService.printThermalReceipt(delivery);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt, color: Colors.green),
              ),
              title: Text('Facture client'),
              subtitle: Text('PDF avec TVA'),
              onTap: () {
                Navigator.pop(context);
                _printService.printInvoice(delivery);
              },
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          Container(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tout',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                SizedBox(width: 8),
                _FilterChip(
                  label: 'Aujourd\'hui',
                  selected: _filter == 'today',
                  onTap: () => setState(() => _filter = 'today'),
                ),
                SizedBox(width: 8),
                _FilterChip(
                  label: '7 jours',
                  selected: _filter == 'week',
                  onTap: () => setState(() => _filter = 'week'),
                ),
                Spacer(),
                Text(
                  '${_filteredDeliveries.length} livraison(s)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          // Liste
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.orange))
                : _filteredDeliveries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              'Aucune livraison',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        color: Colors.orange,
                        child: ListView.builder(
                          padding: EdgeInsets.all(12),
                          itemCount: _filteredDeliveries.length,
                          itemBuilder: (context, index) {
                            final delivery = _filteredDeliveries[index];
                            final order = delivery.order;
                            return Card(
                              margin: EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showDeliveryDetails(delivery),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: delivery.isDelivered
                                                  ? Colors.green.shade50
                                                  : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              delivery.isDelivered
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              color: delivery.isDelivered
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  order.cafeteria?.name ?? 'Client',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  _formatDate(delivery.deliveredAt ?? delivery.createdAt),
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${order.total.toStringAsFixed(0)} DA',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: delivery.isPaid
                                                      ? Colors.green.shade100
                                                      : Colors.orange.shade100,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  delivery.isPaid ? 'Payé' : 'Crédit',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: delivery.isPaid
                                                        ? Colors.green.shade700
                                                        : Colors.orange.shade700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      // Articles résumé
                                      Text(
                                        '${order.items.length} article(s): ${order.items.map((i) => '${i.quantity}x ${i.productName}').join(', ')}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 12),
                                      // Bouton imprimer
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _showPrintOptions(delivery),
                                          icon: Icon(Icons.print, size: 18),
                                          label: Text('Imprimer le bon'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.blue,
                                            side: BorderSide(color: Colors.blue.shade200),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showDeliveryDetails(Delivery delivery) {
    final order = delivery.order;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.local_shipping, color: Colors.orange, size: 28),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.cafeteria?.name ?? 'Client',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatDate(delivery.deliveredAt ?? delivery.createdAt),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Text('Articles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 12),
              ...order.items.map((item) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${item.quantity}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Text(item.productName)),
                    Text('${item.totalPrice.toStringAsFixed(0)} DA'),
                  ],
                ),
              )),
              Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '${order.total.toStringAsFixed(0)} DA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green.shade700),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Collecté'),
                  Text('${delivery.amountCollected.toStringAsFixed(0)} DA'),
                ],
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showPrintOptions(delivery);
                  },
                  icon: Icon(Icons.print),
                  label: Text('IMPRIMER LE BON', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.orange : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[700],
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
