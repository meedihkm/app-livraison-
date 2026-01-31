// =====================================================
// PAGE: Statistics Page - Statistiques complètes client/livreur
// Filtres avancés, graphiques, export
// =====================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/financial_models.dart';
import '../../../../core/services/financial_service_v2.dart';
import '../../../../core/utils/print_utils.dart';
import '../widgets/finance_filters.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with SingleTickerProviderStateMixin {
  final _service = FinancialServiceV2();
  final _printService = PrintService();
  
  late TabController _tabController;
  
  bool _isLoading = true;
  FinancialOverview? _overview;
  
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateTo = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final overview = await _service.getOverview(dateFrom: _dateFrom, dateTo: _dateTo);
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques Détaillées'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Par Client'),
            Tab(icon: Icon(Icons.motorcycle), text: 'Par Livreur'),
          ],
        ),
      ),
      body: _isLoading || _overview == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FinanceFilters(
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                    onDateChanged: (from, to) {
                      setState(() {
                        _dateFrom = from;
                        _dateTo = to;
                      });
                      _loadData();
                    },
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ClientStatisticsTab(stats: _overview!.topClients),
                      _DelivererStatisticsTab(
                        stats: _overview!.delivererStats,
                        onPrint: () => _printService.printDelivererStats(
                          context: context,
                          stats: _overview!.delivererStats,
                          dateFrom: _dateFrom,
                          dateTo: _dateTo,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ClientStatisticsTab extends StatelessWidget {
  final List<TopClient> stats;

  const _ClientStatisticsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);

    if (stats.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    // Calculer le total
    final totalRevenue = stats.fold<double>(0, (sum, c) => sum + c.totalRevenue);
    final totalOrders = stats.fold<int>(0, (sum, c) => sum + c.orderCount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Résumé global
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Clients actifs',
                  value: '${stats.length}',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                _StatItem(
                  label: 'CA Total',
                  value: currencyFormat.format(totalRevenue),
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
                _StatItem(
                  label: 'Commandes',
                  value: '$totalOrders',
                  icon: Icons.shopping_cart,
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Liste détaillée
        const Text(
          'Détail par Client',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...stats.asMap().entries.map((entry) {
          final index = entry.key;
          final client = entry.value;
          final percentage = totalRevenue > 0 
              ? (client.totalRevenue / totalRevenue * 100).toStringAsFixed(1)
              : '0';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: _getRankColor(index),
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
              ),
              title: Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${client.orderCount} commandes'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(client.totalRevenue),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text('$percentage% du CA', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDetailRow('Total payé', currencyFormat.format(client.totalPaid)),
                      _buildDetailRow('Dette actuelle', currencyFormat.format(client.totalDebt), 
                        valueColor: client.totalDebt > 0 ? Colors.red : null),
                      _buildDetailRow('Panier moyen', 
                        currencyFormat.format(client.orderCount > 0 ? client.totalRevenue / client.orderCount : 0)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0: return Colors.amber; // Or
      case 1: return Colors.grey[400]!; // Argent
      case 2: return Colors.orange[300]!; // Bronze
      default: return Colors.blue;
    }
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}

class _DelivererStatisticsTab extends StatelessWidget {
  final List<DelivererStat> stats;
  final VoidCallback onPrint;

  const _DelivererStatisticsTab({required this.stats, required this.onPrint});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);

    if (stats.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    // Calculer les totaux
    final totalDeliveries = stats.fold<int>(0, (sum, s) => sum + s.totalDeliveries);
    final totalDelivered = stats.fold<int>(0, (sum, s) => sum + s.deliveredCount);
    final totalCollected = stats.fold<double>(0, (sum, s) => sum + s.amountCollected);
    final avgSuccessRate = totalDeliveries > 0 
        ? (totalDelivered / totalDeliveries * 100).toStringAsFixed(1)
        : '0';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: onPrint,
              icon: const Icon(Icons.print),
              label: const Text('Imprimer le rapport'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Résumé global
        Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'RÉSUMÉ GLOBAL',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      label: 'Livraisons',
                      value: '$totalDeliveries',
                      icon: Icons.local_shipping,
                      color: Colors.blue,
                    ),
                    _StatItem(
                      label: 'Taux réussite',
                      value: '$avgSuccessRate%',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                    _StatItem(
                      label: 'Collecté',
                      value: currencyFormat.format(totalCollected),
                      icon: Icons.account_balance_wallet,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Classement
        const Text(
          'Classement des Livreurs',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...stats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          final successRate = stat.totalDeliveries > 0
              ? (stat.deliveredCount / stat.totalDeliveries * 100).toStringAsFixed(1)
              : '0';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getRankColor(index),
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
              ),
              title: Text(stat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${stat.deliveredCount}/${stat.totalDeliveries} livrées ($successRate%)'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(stat.amountCollected),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const Text('collectés', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0: return Colors.amber;
      case 1: return Colors.grey[400]!;
      case 2: return Colors.orange[300]!;
      default: return Colors.blue;
    }
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
