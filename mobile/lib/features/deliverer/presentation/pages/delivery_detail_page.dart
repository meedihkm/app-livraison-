import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/database/sync_service.dart';
import '../../../../core/models/delivery_model.dart';
import '../../../../core/models/debt_model.dart';
import '../../../../core/models/packaging_model.dart';
import '../../../admin/presentation/widgets/record_debt_payment_modal.dart';
import '../widgets/record_packaging_modal.dart';

class DeliveryDetailPage extends StatefulWidget {
  final Delivery delivery;
// ... (skip lines to _confirmDelivery)

  DeliveryDetailPage({required this.delivery});

  @override
  _DeliveryDetailPageState createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage> {
  final ApiService _apiService = ApiService();
  final _commentController = TextEditingController();
  final _amountController = TextEditingController();
  String _paymentStatus = 'unpaid';
  bool _isSubmitting = false;
  CustomerDebt? _customerDebt;
  List<PackagingBalance> _packagingBalance = [];

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.delivery.order.total.toStringAsFixed(2);
    _loadDebt();
    _loadPackagingBalance();
  }

  Future<void> _loadDebt() async {
    if (widget.delivery.order.cafeteria?.id != null) {
      try {
        final debt = await _apiService.getCustomerDebt(widget.delivery.order.cafeteria!.id);
        if (mounted) setState(() => _customerDebt = CustomerDebt.fromJson(debt));
      } catch (e) {
        // Ignorer erreur silencieusement ou logger
      }
    }
  }

  Future<void> _loadPackagingBalance() async {
    if (widget.delivery.order.cafeteria?.id != null) {
      try {
        final result = await _apiService.getCustomerPackagingBalance(widget.delivery.order.cafeteria!.id);
        if (result['success'] == true && result['data'] != null && mounted) {
          setState(() {
            _packagingBalance = (result['data'] as List)
                .map((e) => PackagingBalance.fromJson(e as Map<String, dynamic>))
                .toList();
          });
        }
      } catch (e) {
        // Ignorer erreur silencieusement
      }
    }
  }

  void _showPackagingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecordPackagingModal(
        customerId: widget.delivery.order.cafeteria!.id,
        customerName: widget.delivery.order.cafeteria?.name ?? 'Client',
        deliveryId: widget.delivery.id,
        currentBalance: _packagingBalance,
        onSuccess: _loadPackagingBalance,
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelivery() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final amountCollected = double.tryParse(_amountController.text) ?? 0;
    final statusData = {
      'status': 'delivered',
      'paymentStatus': _paymentStatus,
      'amountCollected': amountCollected,
      'comment': _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
    };

    final syncService = SyncService();
    // Offline Logic
    if (!syncService.isOnline) {
       final offlinePayload = Map<String, dynamic>.from(statusData);
       offlinePayload['deliveryId'] = widget.delivery.id;
       
       await syncService.addOfflineAction('UPDATE_DELIVERY', offlinePayload);
       
       setState(() => _isSubmitting = false);
       Navigator.pop(context, true);
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hors ligne : Validation enregistrée'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _apiService.updateDeliveryStatus(widget.delivery.id, statusData);

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Livraison confirmée'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showPaymentModal() {
    if (_customerDebt == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecordDebtPaymentModal(
        debt: _customerDebt!,
        onSuccess: () {
          _loadDebt();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Paiement enregistré avec succès')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final delivery = widget.delivery;
    final order = delivery.order;

    return Scaffold(
      appBar: AppBar(
        title: Text('Livraison #${delivery.id}'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order info
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informations commande',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text('Commande #${order.id}'),
                    Text('Cafétéria: ${order.cafeteria?.name ?? 'N/A'}'),
                    if (order.cafeteria?.phone != null)
                      Text('Téléphone: ${order.cafeteria!.phone}'),
                    Text('Total: ${order.total.toStringAsFixed(2)} €'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            if (_customerDebt != null && _customerDebt!.hasDebt) ...[
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Dette Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                          Text('${_customerDebt!.totalDebt.toStringAsFixed(0)} DA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showPaymentModal,
                          icon: Icon(Icons.attach_money),
                          label: Text('Encaisser Paiement Dette', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            // Packaging Balance Card
            if (_packagingBalance.isNotEmpty || widget.delivery.order.cafeteria?.id != null)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.inventory_2, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Consignes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _showPackagingModal,
                            icon: Icon(Icons.add),
                            label: Text('Gérer'),
                          ),
                        ],
                      ),
                      if (_packagingBalance.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Aucune consigne en cours', style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ..._packagingBalance.where((b) => b.outstanding != 0).map((balance) => Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(balance.typeName),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: balance.outstanding > 0 ? Colors.orange : Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${balance.outstanding}',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 16),

            // Items list
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Articles à livrer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    ...order.items.map((item) => Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('${item.productName} x${item.quantity}'),
                          ),
                          Text(
                            '${item.totalPrice.toStringAsFixed(2)} €',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )),
                    Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${order.total.toStringAsFixed(2)} €',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Delivery confirmation form
            if (delivery.isInProgress) ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirmer la livraison',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Payment status
                      Text(
                        'Statut du paiement',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('Payé'),
                              value: 'paid',
                              // ignore: deprecated_member_use
                              groupValue: _paymentStatus,
                              // ignore: deprecated_member_use
                              onChanged: (value) {
                                setState(() => _paymentStatus = value!);
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('Non payé'),
                              value: 'unpaid',
                              // ignore: deprecated_member_use
                              groupValue: _paymentStatus,
                              // ignore: deprecated_member_use
                              onChanged: (value) {
                                setState(() => _paymentStatus = value!);
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      
                      // Amount collected
                      TextField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Montant collecté (€)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        enabled: _paymentStatus == 'paid',
                      ),
                      SizedBox(height: 16),
                      
                      // Comment
                      TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          labelText: 'Commentaire (optionnel)',
                          border: OutlineInputBorder(),
                          hintText: 'Remarques sur la livraison...',
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 20),
                      
                      // Confirm button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _confirmDelivery,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  'Confirmer la livraison',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Delivery info (if already delivered)
            if (delivery.isDelivered) ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Livraison terminée',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade600,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text('Statut paiement: ${delivery.isPaid ? 'Payé' : 'Non payé'}'),
                      Text('Montant collecté: ${delivery.amountCollected.toStringAsFixed(2)} €'),
                      if (delivery.comment != null && delivery.comment!.isNotEmpty)
                        Text('Commentaire: ${delivery.comment}'),
                      if (delivery.deliveredAt != null)
                        Text('Livré le: ${delivery.deliveredAt}'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}