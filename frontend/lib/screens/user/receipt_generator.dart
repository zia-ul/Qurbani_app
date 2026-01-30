import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

Future<File> generateReceiptPDF(Map<String, dynamic>? orderData) async {
  if (orderData == null) {
    throw Exception("Order data is null");
  }

  final pdf = pw.Document();

  // Correct keys from your API
  final orderId =
      orderData['id']?.toString() ??
      DateTime.now().millisecondsSinceEpoch.toString();
  final paymentStatus = orderData['payment_status'] ?? 'N/A';
  final deliveryStatus = orderData['delivery_status'] ?? 'N/A';
  final adminName = orderData['admin_name'] ?? 'N/A';
  final adminPhone = orderData['admin_phone'] ?? 'N/A';
  final adminAddress = orderData['admin_address'] ?? 'N/A';

  final animals = orderData['animals'] is List
      ? List<Map<String, dynamic>>.from(orderData['animals'])
      : [];

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
              "Animals",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),

            if (animals.isEmpty)
              pw.Text("No animals found.")
            else
              pw.Column(
                children: animals.map((animal) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Type: ${animal['animal_type'] ?? 'N/A'}"),
                        pw.Text("Breed: ${animal['breed'] ?? 'N/A'}"),
                        pw.Text("Price: ₹${animal['price'] ?? 'N/A'}"),
                        pw.Text("Weight: ${animal['weight'] ?? 'N/A'}"),
                        pw.Text("Barcode: ${animal['barcode'] ?? 'N/A'}"),
                        pw.Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ),

            pw.SizedBox(height: 20),
            pw.Text(
              "Thank you for choosing our Qurbani service!",
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
          ],
        );
      },
    ),
  );

  // Ensure directory exists
  final dir = await getApplicationDocumentsDirectory();
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final file = File("${dir.path}/Qurbani_Receipt_$orderId.pdf");

  await file.writeAsBytes(await pdf.save());
  return file;
}
