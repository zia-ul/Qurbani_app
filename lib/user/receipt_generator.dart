import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

Future<File> generateReceiptPDF(Map<String, dynamic> orderData) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "Qurbani Receipt",
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),

            pw.Text("Order ID: ${orderData['orderId']}"),
            pw.Text("User ID: ${orderData['userId']}"),
            pw.Text("Qurbani Day: ${orderData['qurbaniDay']}"),
            pw.Text("Payment Method: ${orderData['paymentMethod']}"),
            pw.Text("Payment Status: ${orderData['paymentStatus']}"),
            pw.SizedBox(height: 10),

            pw.Text(
              "Delivery Address:",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(orderData['deliveryAddress']),
            pw.SizedBox(height: 15),

            pw.Text(
              "Items:",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),

            pw.Column(
              children: List.generate(orderData['cartItems'].length, (i) {
                final item = orderData['cartItems'][i];
                return pw.Text(
                  "${i + 1}. ${item['name']} - ₹${item['price']} × ${item['shares']} shares",
                );
              }),
            ),

            pw.SizedBox(height: 15),
            pw.Divider(),

            pw.Text(
              "Total Amount: ₹${orderData['totalAmount']}",
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
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

  final dir = await getApplicationDocumentsDirectory();
  final file = File("${dir.path}/Qurbani_Receipt_${orderData['orderId']}.pdf");

  await file.writeAsBytes(await pdf.save());
  return file;
}
