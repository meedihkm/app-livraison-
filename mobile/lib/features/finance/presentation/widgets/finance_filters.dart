// =====================================================
// WIDGET: Finance Filters - Filtres de période réutilisables
// Utilisé dans FinanceDashboardPage
// =====================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FinanceFilters extends StatelessWidget {
  final DateTime dateFrom;
  final DateTime dateTo;
  final Function(DateTime, DateTime) onDateChanged;

  const FinanceFilters({
    super.key,
    required this.dateFrom,
    required this.dateTo,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Période', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQuickFilter('Aujourd\'hui', () {
                  final now = DateTime.now();
                  onDateChanged(
                    DateTime(now.year, now.month, now.day),
                    now,
                  );
                }),
                const SizedBox(width: 8),
                _buildQuickFilter('Cette semaine', () {
                  final now = DateTime.now();
                  onDateChanged(
                    now.subtract(Duration(days: now.weekday - 1)),
                    now,
                  );
                }),
                const SizedBox(width: 8),
                _buildQuickFilter('Ce mois', () {
                  final now = DateTime.now();
                  onDateChanged(
                    DateTime(now.year, now.month, 1),
                    now,
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Du',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(dateFormat.format(dateFrom)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Au',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(dateFormat.format(dateTo)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilter(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: Colors.green[50],
      side: BorderSide(color: Colors.green[200]!),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? dateFrom : dateTo,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      if (isFrom) {
        onDateChanged(picked, dateTo);
      } else {
        onDateChanged(dateFrom, picked);
      }
    }
  }
}
