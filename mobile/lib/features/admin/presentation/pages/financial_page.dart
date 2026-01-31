// =====================================================
// PAGE : Finance - Simplifiée et Fonctionnelle
// Utilise l'API unifiée /api/financial/*
// =====================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/financial_service.dart';
import '../widgets/financial_stat_card.dart';

class FinancialPage extends StatefulWidget {
  const FinancialPage({super.key});

  @override
  State<FinancialPage> createState() => _FinancialPageState();
}

class _FinancialPageState extends State<FinancialPage> {
  final _financialService = FinancialService();

  bool _isLoading = true;
  String? _error;

  // Données
  Map<String, dynamic>? _overview;
  List<dynamic> _debts = [];

  // Filtres
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _selectedPeriod = 'today'; // today, week, month, custom

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Calculer les dates selon la période sélectionnée
      DateTime? dateFrom;
      DateTime? dateTo;

      switch (_selectedPeriod) {
        case 'today':
          dateFrom = DateTime.now().copyWith(hour: 0, minute: 0, second: 0);
          dateTo = DateTime.now().copyWith(hour: 23, minute: 59, second: 59);
          break;
        case 'week':
          final now = DateTime.now();
          dateFrom = now.subtract(Duration(days: now.weekday - 1));
          dateTo = now;
          break;
        case 'month':
          final now = DateTime.now();
          dateFrom = DateTime(now.year, now.month);
          dateTo = now;
          break;
        case 'custom':
          dateFrom = _dateFrom;
          dateTo = _dateTo;
          break;
      }

      // Charger les données
      final results = await Future.wait([
        _financialService.getFinancialOverview(
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
        _financialService.getDebts(limit: 100),
      ]);

      setState(() {
        _overview = results[0]['data'];
        _debts = results[1]['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erreur: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sélecteur de période
                        _buildPeriodSelector(),
                        const SizedBox(height: 16),

                        // Statistiques principales
                        if (_overview != null) ...[
                          _buildSummarySection(),
                          const SizedBox(height: 24),

                          // Top clients
                          _buildTopClientsSection(),
                          const SizedBox(height: 24),

                          // Stats livreurs
                          _buildDelivererStatsSection(),
                          const SizedBox(height: 24),
                        ],

                        // Liste des dettes
                        _buildDebtsSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            _buildPeriodChip('Aujourd\'hui', 'today'),
            const SizedBox(width: 8),
            _buildPeriodChip('Semaine', 'week'),
            const SizedBox(width: 8),
            _buildPeriodChip('Mois', 'month'),
            const SizedBox(width: 8),
            _buildPeriodChip('Personnalisé', 'custom'),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedPeriod = value);
          if (value != 'custom') {
            _loadData();
          } else {
            _showDateRangePicker();
          }
        }
      },
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFrom != null && _dateTo != null ? DateTimeRange(start: _dateFrom!, end: _dateTo!) : null,
    );

    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
      _loadData();
    }
  }

  Widget _buildSummarySection() {
    final summary = _overview!['summary'];
    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Résumé',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            FinancialStatCard(
              title: 'Revenus Totaux',
              value: currencyFormat.format(summary['totalRevenue'] ?? 0),
              icon: Icons.attach_money,
              color: Colors.green,
            ),
            FinancialStatCard(
              title: 'Collecté',
              value: currencyFormat.format(summary['totalCollected'] ?? 0),
              icon: Icons.account_balance_wallet,
              color: Colors.blue,
            ),
            FinancialStatCard(
              title: 'Dettes',
              value: currencyFormat.format(summary['totalUnpaid'] ?? 0),
              icon: Icons.warning,
              color: Colors.orange,
            ),
            FinancialStatCard(
              title: 'Commandes',
              value: '${summary['totalOrders'] ?? 0}',
              icon: Icons.shopping_cart,
              color: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopClientsSection() {
    final topClients = _overview!['topClients'] as List? ?? [];
    if (topClients.isEmpty) return const SizedBox.shrink();

    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top 5 Clients',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topClients.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final client = topClients[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                title: Text(client['name'] ?? 'Client'),
                subtitle: Text(
                  '${client['orderCount']} commandes • ${currencyFormat.format(client['totalRevenue'] ?? 0)}',
                ),
                trailing: client['totalDebt'] > 0
                    ? Chip(
                        label: Text(
                          currencyFormat.format(client['totalDebt']),
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.orange.shade100,
                      )
                    : null,
                onTap: () {
                  // TODO: Naviguer vers détail client
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDelivererStatsSection() {
    final delivererStats = _overview!['delivererStats'] as List? ?? [];
    if (delivererStats.isEmpty) return const SizedBox.shrink();

    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistiques Livreurs',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: delivererStats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final deliverer = delivererStats[index];
              final totalDeliveries = deliverer['totalDeliveries'] ?? 0;
              final deliveredCount = deliverer['deliveredCount'] ?? 0;
              final successRate =
                  totalDeliveries > 0 ? (deliveredCount / totalDeliveries * 100).toStringAsFixed(0) : '0';

              return ListTile(
                leading: CircleAvatar(
                  child: Text(deliverer['name']?.substring(0, 1) ?? 'L'),
                ),
                title: Text(deliverer['name'] ?? 'Livreur'),
                subtitle: Text(
                  '$deliveredCount/$totalDeliveries livrées ($successRate%) • ${currencyFormat.format(deliverer['amountCollected'] ?? 0)}',
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDebtsSection() {
    if (_debts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.check_circle, size: 48, color: Colors.green),
                SizedBox(height: 16),
                Text('Aucune dette en cours'),
              ],
            ),
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clients avec Dette (${_debts.length})',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _debts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final debt = _debts[index];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(debt['name'] ?? 'Client'),
                subtitle: Text(
                  '${debt['unpaidOrders']} commandes impayées',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(debt['totalDebt'] ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                onTap: () => _showDebtDetail(debt['customerId']),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showDebtDetail(String customerId) async {
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _financialService.getCustomerDebt(customerId);
      Navigator.pop(context); // Fermer le loading

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => _DebtDetailDialog(data: result['data']),
      );
    } catch (e) {
      Navigator.pop(context);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
}

// Dialog pour afficher le détail d'une dette
class _DebtDetailDialog extends StatelessWidget {
  const _DebtDetailDialog({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final customer = data['customer'];
    final unpaidOrders = data['unpaidOrders'] as List? ?? [];
    final totalDebt = data['totalDebt'] ?? 0;
    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);

    return AlertDialog(
      title: Text(customer['name'] ?? 'Client'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dette totale: ${currencyFormat.format(totalDebt)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Commandes impayées:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: unpaidOrders.length,
                itemBuilder: (context, index) {
                  final order = unpaidOrders[index];
                  return ListTile(
                    dense: true,
                    title: Text('Commande #${order['orderNumber']}'),
                    subtitle: Text(
                      'Reste: ${currencyFormat.format(order['remaining'])}',
                    ),
                    trailing: Chip(
                      label: Text(order['paymentStatus'] ?? 'unpaid'),
                      backgroundColor:
                          order['paymentStatus'] == 'partial' ? Colors.orange.shade100 : Colors.red.shade100,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // TODO: Ouvrir dialog d'enregistrement de paiement
          },
          child: const Text('Enregistrer un paiement'),
        ),
      ],
    );
  }
}
