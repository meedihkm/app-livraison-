import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/services/financial_service.dart';

class DebtCollectionPage extends StatefulWidget {
  const DebtCollectionPage({super.key});

  @override
  _DebtCollectionPageState createState() => _DebtCollectionPageState();
}

class _DebtCollectionPageState extends State<DebtCollectionPage> {
  final ApiService _apiService = ApiService();
  final FinancialService _financialService = FinancialService();

  List<dynamic> _clientsWithDebts = [];
  List<dynamic> _myCollections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        _financialService.getDebts(),
        _financialService.getMyCollections(),
      ]);

      setState(() {
        _clientsWithDebts = (results[0]['data'] as List?) ?? [];
        _myCollections = (results[1]['data'] as List?) ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showCollectDebtDialog(Map<String, dynamic> client) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final debtValue = client['debt'];
    final debt = (debtValue is num) ? debtValue.toDouble() : 0.0;

    amountController.text = debt.toStringAsFixed(0);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Collecter dette'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client: ${client['name']}', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Dette: ${debt.toStringAsFixed(0)} DA',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                  ],
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                decoration: InputDecoration(
                  labelText: 'Montant collecté (DA)',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Note (optionnel)',
                  hintText: 'Ex: Paiement en espèces',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2E7D32)),
            child: Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      final amount = double.tryParse(amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
        );
        return;
      }

      try {
        final paymentResult = await _financialService.recordPayment(
          customerId: client['id'] as String,
          amount: amount,
          notes: notesController.text.isNotEmpty ? notesController.text : 'Collecte de dette',
        );

        if (paymentResult['success'] == true) {
          _showPaymentResult(paymentResult['data'] as Map<String, dynamic>);
          if (mounted) {
            await _loadData();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
    }

    amountController.dispose();
    notesController.dispose();
  }

  void _showPaymentResult(Map<String, dynamic> data) {
    final ordersAffected = data['orders_affected'] as List? ?? [];
    final debtCleared = data['debt_cleared'] == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Paiement enregistré'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Montant: ${data['amount_applied']} DA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 12),
            Text('Répartition:', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            ...ordersAffected.map((order) => Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Commande #${order['order_number']}: ${order['amount_applied']} DA',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: debtCleared ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    debtCleared ? Icons.celebration : Icons.info_outline,
                    color: debtCleared ? Colors.green : Colors.blue,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      debtCleared ? 'Dette soldée !' : 'Nouvelle dette: ${data['debt_after']} DA',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: debtCleared ? Colors.green.shade700 : Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.orange,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Clients avec dettes
            Text('Clients avec dettes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),

            if (_clientsWithDebts.isEmpty)
              Container(
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 48, color: Colors.grey[400]),
                      SizedBox(height: 12),
                      Text('Aucune dette en cours', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              )
            else
              ...(_clientsWithDebts.map((client) => Card(
                    margin: EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        child: Icon(Icons.warning_amber, color: Colors.red),
                      ),
                      title: Text(client['name'] ?? 'Client', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${client['order_count'] ?? 0} commande(s) impayée(s)'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${_parseDouble(client['debt']).toStringAsFixed(0)} DA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 16,
                              )),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Collecter',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      onTap: () => _showCollectDebtDialog(client),
                    ),
                  ))),

            SizedBox(height: 32),

            // Section: Mes collectes du jour
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mes collectes du jour', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ],
            ),
            SizedBox(height: 12),

            if (_myCollections.isEmpty)
              Container(
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.payment, size: 48, color: Colors.grey[400]),
                      SizedBox(height: 12),
                      Text('Aucune collecte aujourd\'hui', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              )
            else
              ...(_myCollections.map((collection) {
                final date = DateTime.tryParse(collection['created_at'] ?? '');
                final isToday = date != null &&
                    date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;

                if (!isToday) return SizedBox.shrink();

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      child: Icon(Icons.check_circle, color: Colors.green),
                    ),
                    title: Text(collection['client_name'] ?? 'Client', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      '${_parseDouble(collection['amount']).toStringAsFixed(0)} DA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              })),
          ],
        ),
      ),
    );
  }
}
