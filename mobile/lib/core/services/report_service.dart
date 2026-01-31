import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  Future<void> generateDailyReport({
    required DateTime date,
    required Map<String, dynamic> stats,
    required List<dynamic> orders,
    required List<dynamic> deliveries,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(30),
        build: (context) => [
          // Header
          pw.Center(
            child: pw.Text('RAPPORT JOURNALIER', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Text('${date.day}/${date.month}/${date.year}', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.SizedBox(height: 20),

          // Résumé
          pw.Text('RÉSUMÉ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildStatsTable(stats),
          pw.SizedBox(height: 20),

          // Commandes
          pw.Text('COMMANDES (${orders.length})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildOrdersTable(orders),
          pw.SizedBox(height: 20),

          // Livraisons
          pw.Text('LIVRAISONS (${deliveries.length})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildDeliveriesTable(deliveries),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _buildStatsTable(Map<String, dynamic> stats) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('Chiffre d\'affaires', bold: true),
            _cell('Collecté', bold: true),
            _cell('Impayé', bold: true),
            _cell('Commandes', bold: true),
          ],
        ),
        pw.TableRow(
          children: [
            _cell('${_formatNum(stats['totalCA'])} DA'),
            _cell('${_formatNum(stats['collected'])} DA'),
            _cell('${_formatNum(stats['unpaid'])} DA'),
            _cell('${stats['orderCount'] ?? 0}'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildOrdersTable(List<dynamic> orders) {
    if (orders.isEmpty) {
      return pw.Text('Aucune commande', style: pw.TextStyle(color: PdfColors.grey));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('Client', bold: true),
            _cell('Total', bold: true),
            _cell('Payé', bold: true),
            _cell('Statut', bold: true),
          ],
        ),
        ...orders.take(20).map((o) => pw.TableRow(
          children: [
            _cell(o['customer']?['name'] ?? 'N/A'),
            _cell('${_formatNum(o['total'])} DA'),
            _cell('${_formatNum(o['amountPaid'])} DA'),
            _cell(_getStatusText(o['status'])),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildDeliveriesTable(List<dynamic> deliveries) {
    if (deliveries.isEmpty) {
      return pw.Text('Aucune livraison', style: pw.TextStyle(color: PdfColors.grey));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('Client', bold: true),
            _cell('Livreur', bold: true),
            _cell('Collecté', bold: true),
            _cell('Statut', bold: true),
          ],
        ),
        ...deliveries.take(20).map((d) => pw.TableRow(
          children: [
            _cell(d['order']?['customer']?['name'] ?? 'N/A'),
            _cell(d['deliverer']?['name'] ?? 'N/A'),
            _cell('${_formatNum(d['amountCollected'])} DA'),
            _cell(_getDeliveryStatusText(d['status'])),
          ],
        )),
      ],
    );
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(6),
      child: pw.Text(text, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10) : pw.TextStyle(fontSize: 10)),
    );
  }

  String _formatNum(dynamic value) {
    if (value == null) return '0';
    if (value is double) return value.toStringAsFixed(0);
    if (value is int) return value.toString();
    return value.toString();
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'locked': return 'Verrouillée';
      case 'in_delivery': return 'En livraison';
      case 'delivered': return 'Livrée';
      default: return status ?? 'N/A';
    }
  }

  String _getDeliveryStatusText(String? status) {
    switch (status) {
      case 'assigned': return 'Assignée';
      case 'delivered': return 'Livrée';
      case 'failed': return 'Échouée';
      case 'postponed': return 'Reportée';
      default: return status ?? 'N/A';
    }
  }

  // Rapport financier mensuel
  Future<void> generateMonthlyFinancialReport({
    required int month,
    required int year,
    required List<dynamic> orders,
    required List<dynamic> debts,
  }) async {
    final pdf = pw.Document();
    
    double totalCA = 0, totalCollected = 0;
    for (var o in orders) {
      totalCA += _parseDouble(o['total']);
      totalCollected += _parseDouble(o['amountPaid']);
    }
    double totalDebt = debts.fold(0.0, (sum, d) => sum + _parseDouble(d['debt']));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(30),
        build: (context) => [
          pw.Center(child: pw.Text('RAPPORT FINANCIER', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 5),
          pw.Center(child: pw.Text('$month/$year', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700))),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.SizedBox(height: 20),

          // Résumé financier
          pw.Container(
            padding: pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue)),
            child: pw.Column(
              children: [
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Chiffre d\'affaires total:'),
                  pw.Text('${totalCA.toStringAsFixed(0)} DA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]),
                pw.SizedBox(height: 8),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Total collecté:'),
                  pw.Text('${totalCollected.toStringAsFixed(0)} DA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                ]),
                pw.SizedBox(height: 8),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Total impayé:'),
                  pw.Text('${(totalCA - totalCollected).toStringAsFixed(0)} DA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                ]),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Taux de recouvrement:'),
                  pw.Text('${totalCA > 0 ? ((totalCollected / totalCA) * 100).toStringAsFixed(1) : 0}%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Dettes par client
          pw.Text('DETTES PAR CLIENT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          if (debts.isEmpty)
            pw.Text('Aucune dette', style: pw.TextStyle(color: PdfColors.grey))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [_cell('Client', bold: true), _cell('Dette', bold: true), _cell('Commandes', bold: true)],
                ),
                ...debts.map((d) => pw.TableRow(children: [
                  _cell(d['name'] ?? 'N/A'),
                  _cell('${_formatNum(d['debt'])} DA'),
                  _cell('${d['order_count'] ?? 0}'),
                ])),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.red100),
                  children: [
                    _cell('TOTAL', bold: true),
                    _cell('${totalDebt.toStringAsFixed(0)} DA', bold: true),
                    _cell(''),
                  ],
                ),
              ],
            ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}
