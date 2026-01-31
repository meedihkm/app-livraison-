import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/delivery_model.dart';
import '../models/order_model.dart';

class PrintService {
  static final PrintService _instance = PrintService._internal();
  factory PrintService() => _instance;
  PrintService._internal();

  Future<void> printDeliverySlip(Delivery delivery) async {
    final pdf = pw.Document();
    final order = delivery.order;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Text('BON DE LIVRAISON', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.SizedBox(height: 10),

            // Infos client
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Client:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(order.cafeteria?.name ?? 'N/A'),
                    if (order.cafeteria?.phone != null) pw.Text(order.cafeteria!.phone!),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(_formatDate(DateTime.now())),
                    pw.Text('N° ${delivery.id.substring(0, 8)}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Tableau articles
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell('Article', bold: true),
                    _tableCell('Qté', bold: true, center: true),
                    _tableCell('P.U', bold: true, center: true),
                    _tableCell('Total', bold: true, center: true),
                  ],
                ),
                // Items
                ...order.items.map((item) => pw.TableRow(
                  children: [
                    _tableCell(item.productName),
                    _tableCell('${item.quantity}', center: true),
                    _tableCell('${item.unitPrice.toStringAsFixed(0)}', center: true),
                    _tableCell('${item.totalPrice.toStringAsFixed(0)}', center: true),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 15),

            // Totaux
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('Total: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('${order.total.toStringAsFixed(0)} DA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('Déjà payé: '),
                      pw.Text('${order.amountPaid.toStringAsFixed(0)} DA'),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 2),
                    ),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('À PAYER: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('${order.remainingAmount.toStringAsFixed(0)} DA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Text('Signature livreur'),
                    pw.SizedBox(height: 30),
                    pw.Container(width: 100, child: pw.Divider()),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('Signature client'),
                    pw.SizedBox(height: 30),
                    pw.Container(width: 100, child: pw.Divider()),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _tableCell(String text, {bool bold = false, bool center = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Étiquette client pour l'atelier (sans prix)
  Future<void> printClientLabel(Order order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(100 * PdfPageFormat.mm, 60 * PdfPageFormat.mm, marginAll: 5 * PdfPageFormat.mm),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Nom du client en gros
            pw.Center(
              child: pw.Text(
                order.cafeteria?.name ?? 'Client',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 6),
            
            // Liste des articles (sans prix)
            ...order.items.map((item) => pw.Padding(
              padding: pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 24,
                    height: 24,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Center(
                      child: pw.Text('${item.quantity}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: pw.Text(item.productName, style: pw.TextStyle(fontSize: 11))),
                ],
              ),
            )),
            
            pw.Spacer(),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),
            
            // Date et heure
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(_formatDate(DateTime.now()), style: pw.TextStyle(fontSize: 8)),
                pw.Text('${order.items.length} article${order.items.length > 1 ? 's' : ''}', style: pw.TextStyle(fontSize: 8)),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // Impression thermique (format ticket)
  Future<void> printThermalReceipt(Delivery delivery) async {
    final pdf = pw.Document();
    final order = delivery.order;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('BON DE LIVRAISON', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text(_formatDate(DateTime.now()), style: pw.TextStyle(fontSize: 8)),
            pw.Divider(),
            pw.Text(order.cafeteria?.name ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ...order.items.map((item) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('${item.quantity}x ${item.productName}', style: pw.TextStyle(fontSize: 9))),
                pw.Text('${item.totalPrice.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 9)),
              ],
            )),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('${order.total.toStringAsFixed(0)} DA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('À PAYER:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('${order.remainingAmount.toStringAsFixed(0)} DA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text('Merci!', style: pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // Facture client avec TVA
  Future<void> printInvoice(Delivery delivery, {double tvaRate = 19}) async {
    final pdf = pw.Document();
    final order = delivery.order;
    final htTotal = order.total / (1 + tvaRate / 100);
    final tvaAmount = order.total - htTotal;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(30),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FACTURE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('N° ${delivery.id.substring(0, 8).toUpperCase()}'),
                    pw.Text('Date: ${_formatDate(DateTime.now())}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('VOTRE ENTREPRISE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Adresse'),
                    pw.Text('Téléphone'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Client
            pw.Container(
              padding: pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('FACTURÉ À:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.SizedBox(height: 5),
                  pw.Text(order.cafeteria?.name ?? 'Client', style: pw.TextStyle(fontSize: 14)),
                  if (order.cafeteria?.phone != null) pw.Text(order.cafeteria!.phone!),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Tableau articles
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell('Description', bold: true),
                    _tableCell('Qté', bold: true, center: true),
                    _tableCell('P.U HT', bold: true, center: true),
                    _tableCell('Total HT', bold: true, center: true),
                  ],
                ),
                ...order.items.map((item) {
                  final unitHT = item.unitPrice / (1 + tvaRate / 100);
                  final totalHT = unitHT * item.quantity;
                  return pw.TableRow(
                    children: [
                      _tableCell(item.productName),
                      _tableCell('${item.quantity}', center: true),
                      _tableCell('${unitHT.toStringAsFixed(2)}', center: true),
                      _tableCell('${totalHT.toStringAsFixed(2)}', center: true),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            // Totaux
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 200,
                child: pw.Column(
                  children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Total HT:'),
                      pw.Text('${htTotal.toStringAsFixed(2)} DA'),
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('TVA (${tvaRate.toStringAsFixed(0)}%):'),
                      pw.Text('${tvaAmount.toStringAsFixed(2)} DA'),
                    ]),
                    pw.Divider(),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Total TTC:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('${order.total.toStringAsFixed(2)} DA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.SizedBox(height: 8),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Déjà payé:'),
                      pw.Text('${order.amountPaid.toStringAsFixed(2)} DA'),
                    ]),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Reste à payer:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                      pw.Text('${order.remainingAmount.toStringAsFixed(2)} DA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                    ]),
                  ],
                ),
              ),
            ),
            pw.Spacer(),

            // Footer
            pw.Center(
              child: pw.Text('Merci pour votre confiance!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
