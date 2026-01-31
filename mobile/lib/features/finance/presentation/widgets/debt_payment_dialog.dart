// =====================================================
// WIDGET: Debt Payment Dialog - Dialog d'encaissement de dette
// Utilise FinancialServiceV2 pour enregistrer le paiement
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/financial_models.dart';
import '../../../../core/services/financial_service_v2.dart';
import '../../../../core/utils/print_utils.dart';

class DebtPaymentDialog extends StatefulWidget {
  final String customerId;
  final String customerName;
  final double totalDebt;

  const DebtPaymentDialog({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.totalDebt,
  });

  @override
  State<DebtPaymentDialog> createState() => _DebtPaymentDialogState();
}

class _DebtPaymentDialogState extends State<DebtPaymentDialog> {
  final _service = FinancialServiceV2();
  final _printService = PrintService();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  PaymentMode _selectedMode = PaymentMode.cash;
  bool _isLoading = false;
  bool _printReceipt = true;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.totalDebt.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Veuillez entrer un montant valide');
      return;
    }

    if (amount > widget.totalDebt) {
      _showError('Le montant ne peut pas dépasser la dette totale');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payment = await _service.recordPayment(
        customerId: widget.customerId,
        amount: amount,
        mode: _selectedMode,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      // Imprimer le reçu si demandé
      if (_printReceipt && mounted) {
        await _printService.printPaymentReceipt(
          context: context,
          customerName: widget.customerName,
          amount: amount,
          mode: _selectedMode,
          date: payment.createdAt,
          collectorName: 'Admin', // TODO: Récupérer le nom de l'utilisateur connecté
          receiptNumber: payment.id.substring(0, 8).toUpperCase(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement enregistré avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Erreur: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);

    return AlertDialog(
      title: const Text('Encaisser un paiement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info client
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Dette: ${currencyFormat.format(widget.totalDebt)}',
                          style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Montant
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Montant à encaisser (DA)',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.all_inclusive, size: 20),
                  tooltip: 'Montant total',
                  onPressed: () {
                    _amountController.text = widget.totalDebt.toStringAsFixed(0);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mode de paiement
            const Text('Mode de paiement:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<PaymentMode>(
              segments: const [
                ButtonSegment(
                  value: PaymentMode.cash,
                  label: Text('Espèces'),
                  icon: Icon(Icons.money),
                ),
                ButtonSegment(
                  value: PaymentMode.check,
                  label: Text('Chèque'),
                  icon: Icon(Icons.account_balance),
                ),
                ButtonSegment(
                  value: PaymentMode.transfer,
                  label: Text('Virement'),
                  icon: Icon(Icons.swap_horiz),
                ),
              ],
              selected: {_selectedMode},
              onSelectionChanged: (value) {
                setState(() => _selectedMode = value.first);
              },
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optionnel)',
                hintText: 'Ex: Paiement partiel, Remise accordée...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Option impression
            CheckboxListTile(
              title: const Text('Imprimer le reçu'),
              value: _printReceipt,
              onChanged: (value) {
                setState(() => _printReceipt = value ?? true);
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _onSubmit,
          icon: _isLoading 
              ? const SizedBox(
                  width: 16, 
                  height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: Text(_isLoading ? 'Enregistrement...' : 'Confirmer le paiement'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
