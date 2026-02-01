// =====================================================
// WIDGET: Finance Summary Cards - Cartes de résumé réutilisables
// Utilise FinancialSummary du modèle existant
// =====================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/financial_models.dart';

class FinanceSummaryCards extends StatelessWidget {
  final FinancialSummary summary;

  const FinanceSummaryCards({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _SummaryCard(
          title: 'Revenus Totaux',
          value: currencyFormat.format(summary.totalRevenue),
          subtitle: '${summary.totalOrders} commandes',
          icon: Icons.attach_money,
          color: Colors.blue,
        ),
        _SummaryCard(
          title: 'Collecté',
          value: currencyFormat.format(summary.totalCollected),
          subtitle: '${(summary.collectionRate * 100).toStringAsFixed(1)}% du total',
          icon: Icons.account_balance_wallet,
          color: Colors.green,
        ),
        _SummaryCard(
          title: 'Dettes',
          value: currencyFormat.format(summary.totalUnpaid),
          subtitle: '${summary.customersWithDebt} clients',
          icon: Icons.warning,
          color: Colors.orange,
        ),
        _SummaryCard(
          title: 'Taux Recouvrement',
          value: '${(summary.collectionRate * 100).toStringAsFixed(1)}%',
          subtitle: '${summary.paidOrders} payées • ${summary.partialOrders} partielles',
          icon: Icons.trending_up,
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.1), Colors.white],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
