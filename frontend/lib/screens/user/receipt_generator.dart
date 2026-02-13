import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

Future<File> generateReceiptPDF(Map<String, dynamic>? orderData) async {
  if (orderData == null) {
    throw Exception("Order data is null");
  }

  final pdf = pw.Document();

  final orderId =
      orderData['id']?.toString() ??
      DateTime.now().millisecondsSinceEpoch.toString();

  final paymentStatus = orderData['payment_status'] ?? 'N/A';

  final shareholders = orderData['shareholders'] is List
      ? List<Map<String, dynamic>>.from(orderData['shareholders'])
      : [];

  // Take first shareholder for delivery status
  final firstShareholder =
      shareholders.isNotEmpty ? shareholders.first : null;

  final deliveryStatus =
      firstShareholder?['delivery_status'] ?? 'N/A';

  final adminName = orderData['admin_name'] ?? 'N/A';
  final adminPhone = orderData['admin_phone'] ?? 'N/A';
  final adminAddress = orderData['admin_address'] ?? 'N/A';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "Qurbani Receipt",
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 10),
            pw.Divider(),

            pw.Text("Order ID: $orderId"),
            pw.Text("Payment Status: $paymentStatus"),
            pw.Text("Delivery Status: $deliveryStatus"),

            pw.SizedBox(height: 10),

            pw.Text(
              "Admin Details",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text("Name: $adminName"),
            pw.Text("Phone: $adminPhone"),
            pw.Text("Address: $adminAddress"),

            pw.SizedBox(height: 15),

            pw.Text(
              "Shareholder Details",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),

            if (shareholders.isEmpty)
              pw.Text("No shareholder data found.")
            else
              pw.Column(
                children: shareholders.map((s) {
                  final hasAnimal =
                      s['animal_type'] != null &&
                      s['animal_type'].toString().isNotEmpty;

                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Shareholder: ${s['shareholder_name'] ?? 'N/A'}",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text("Qurbani Day: ${s['qurbani_day'] ?? 'N/A'}"),
                        pw.Text(
                            "Processing Status: ${s['processing_status'] ?? 'N/A'}"),
                        pw.Text(
                            "Delivery Status: ${s['delivery_status'] ?? 'N/A'}"),
                        pw.Text("Payment Status: ${s['payment_status'] ?? 'N/A'}"),

                        if (hasAnimal) ...[
                          pw.SizedBox(height: 5),
                          pw.Text(
                            "Animal Details",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                              "Type: ${s['animal_type'] ?? 'N/A'}"),
                        ],

                        pw.Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ),

            pw.SizedBox(height: 20),

            pw.Center(
              child: pw.Text(
                "Thank you for choosing our Qurbani service!",
                style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
              ),
            ),
          ],
        );
      },
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final file = File("${dir.path}/Qurbani_Receipt_$orderId.pdf");
  await file.writeAsBytes(await pdf.save());

  return file;
}
