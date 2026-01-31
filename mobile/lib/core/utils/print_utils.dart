// =====================================================
// UTILS: Print Utilities - Service d'impression unifié
// Supporte l'impression de rapports financiers, tickets
// =====================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/financial_models.dart';

/// Service d'impression centralisé
class PrintService {
  static final PrintService _instance = PrintService._internal();
  factory PrintService() => _instance;
  PrintService._internal();

  final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  // ============================================
  // IMPRESSION RAPPORT FINANCIER
  // ============================================
  
  Future<void> printFinancialReport({
    required BuildContext context,
    required FinancialOverview overview,
    required List<CustomerDebt> debts,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? organizationName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildReportHeader(
          'Rapport Financier',
          dateFrom,
          dateTo,
          organizationName,
        ),
        footer: (context) => _buildReportFooter(context),
        build: (context) => [
          _buildSummarySection(overview.summary),
          pw.SizedBox(height: 20),
          _buildTopClientsSection(overview.topClients),
          pw.SizedBox(height: 20),
          _buildDebtsSection(debts),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'rapport_financier_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // ============================================
  // IMPRESSION TICKET DE PAIEMENT
  // ============================================
  
  Future<void> printPaymentReceipt({
    required BuildContext context,
    required String customerName,
    required double amount,
    required PaymentMode mode,
    required DateTime date,
    required String collectorName,
    String? receiptNumber,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, 200 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(8),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('REÇU DE PAIEMENT', 
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text('N°: ${receiptNumber ?? "---"}', style: pw.TextStyle(fontSize: 10)),
            pw.Text(dateFormat.format(date), style: pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 15),
            pw.Text('Client:', style: pw.TextStyle(fontSize: 10)),
            pw.Text(customerName, 
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 15),
            pw.Text('Montant:', style: pw.TextStyle(fontSize: 10)),
            pw.Text(currencyFormat.format(amount),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
            pw.SizedBox(height: 10),
            pw.Text('Mode: ${_getPaymentModeLabel(mode)}', style: pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 15),
            pw.Divider(),
            pw.Text('Perçu par: $collectorName', style: pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 20),
            pw.Text('Merci pour votre confiance!', 
              style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'recu_paiement_${DateFormat('yyyyMMdd_HHmm').format(date)}.pdf',
    );
  }

  // ============================================
  // IMPRESSION STATISTIQUES LIVREUR
  // ============================================
  
  Future<void> printDelivererStats({
    required BuildContext context,
    required List<DelivererStat> stats,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildReportHeader(
          'Statistiques Livreurs',
          dateFrom,
          dateTo,
          null,
        ),
        footer: (context) => _buildReportFooter(context),
        build: (context) => [
          _buildDelivererStatsTable(stats),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'stats_livreurs_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // ============================================
  // WIDGETS PDF PRIVÉS
  // ============================================

  pw.Widget _buildReportHeader(String title, DateTime from, DateTime to, String? orgName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        if (orgName != null) pw.Text(orgName, style: pw.TextStyle(fontSize: 12)),
        pw.Text('Période: ${DateFormat('dd/MM/yyyy').format(from)} - ${DateFormat('dd/MM/yyyy').format(to)}',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildReportFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} sur ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
      ),
    );
  }

  pw.Widget _buildSummarySection(FinancialSummary summary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Résumé Financier', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            _buildSummaryRow('Revenus Totaux', currencyFormat.format(summary.totalRevenue), PdfColors.blue),
            _buildSummaryRow('Collecté', currencyFormat.format(summary.totalCollected), PdfColors.green),
            _buildSummaryRow('Dettes', currencyFormat.format(summary.totalUnpaid), PdfColors.orange),
            _buildSummaryRow('Taux de Recouvrement', '${(summary.collectionRate * 100).toStringAsFixed(1)}%', PdfColors.purple),
          ],
        ),
      ],
    );
  }

  pw.TableRow _buildSummaryRow(String label, String value, PdfColor color) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 10)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, 
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  pw.Widget _buildTopClientsSection(List<TopClient> clients) {
    if (clients.isEmpty) return pw.SizedBox.shrink();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Top 5 Clients', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: ['Client', 'Commandes', 'CA'].map((h) => 
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
              ).toList(),
            ),
            ...clients.map((c) => pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(c.name, style: pw.TextStyle(fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${c.orderCount}', style: pw.TextStyle(fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(currencyFormat.format(c.totalRevenue), style: pw.TextStyle(fontSize: 9))),
              ],
            )),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildDebtsSection(List<CustomerDebt> debts) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Clients avec Dette (${debts.length})', 
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        if (debts.isEmpty)
          pw.Text('Aucune dette en cours', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey100),
                children: ['Client', 'Commandes', 'Dette'].map((h) => 
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                ).toList(),
              ),
              ...debts.map((d) => pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(d.name, style: pw.TextStyle(fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${d.unpaidOrders}', style: pw.TextStyle(fontSize: 9))),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8), 
                    child: pw.Text(currencyFormat.format(d.totalDebt), 
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.orange, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              )),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildDelivererStatsTable(List<DelivererStat> stats) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: ['Livreur', 'Livraisons', 'Délivrées', 'Taux', 'Collecté'].map((h) => 
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ),
          ).toList(),
        ),
        ...stats.map((s) {
          final rate = s.totalDeliveries > 0 ? (s.deliveredCount / s.totalDeliveries * 100).toStringAsFixed(1) : '0';
          return pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(s.name, style: pw.TextStyle(fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${s.totalDeliveries}', style: pw.TextStyle(fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${s.deliveredCount}', style: pw.TextStyle(fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$rate%', style: pw.TextStyle(fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(currencyFormat.format(s.amountCollected), style: pw.TextStyle(fontSize: 9))),
            ],
          );
        }),
      ],
    );
  }

  String _getPaymentModeLabel(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.cash: return 'Espèces';
      case PaymentMode.check: return 'Chèque';
      case PaymentMode.transfer: return 'Virement';
    }
  }
}

/// Extension pour faciliter l'impression depuis les widgets
extension PrintContextExtension on BuildContext {
  PrintService get printService => PrintService();
}
