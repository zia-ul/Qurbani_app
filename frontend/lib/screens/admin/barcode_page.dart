import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:Qurbani/theme/theme.dart';

class BarcodePage extends StatefulWidget {
  final String barcodeValue;

  const BarcodePage({super.key, required this.barcodeValue});

  @override
  State<BarcodePage> createState() => _BarcodePageState();
}

class _BarcodePageState extends State<BarcodePage> {
  final GlobalKey _globalKey = GlobalKey();

  // Theme Colors from reference
  final Color bgParchment = const Color(0xffF2E8D5);

  Future<void> _printBarcode() async {
    try {
      final boundary =
          _globalKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final pdf = pw.Document();
      final pwImage = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  "QURBANI APP - ANIMAL TAG",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Image(pwImage, width: 400),
                pw.SizedBox(height: 10),
                pw.Text(
                  "ID: ${widget.barcodeValue}",
                  style: pw.TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      debugPrint("Print error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgParchment,
      appBar: AppBar(
        title: const Text(
          "Animal Identification",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              // Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner,
                      size: 50,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Scan Identification Tag",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Attach this barcode to the animal for easy tracking during Qurbani.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Barcode Card (The RepaintBoundary covers the white area for clean printing)
              RepaintBoundary(
                key: _globalKey,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryGreen.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      BarcodeWidget(
                        barcode: Barcode.code128(), // Highly scanable standard
                        data: widget.barcodeValue,
                        width: double.infinity,
                        height: 140,
                        drawText:
                            false, // We draw text manually below for better styling
                        padding: const EdgeInsets.all(10),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.barcodeValue,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      const Text(
                        "OFFICIAL ANIMAL ID",
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryGreen,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Action Buttons
              _buildActionButton(
                label: "Print Identification Tag",
                icon: Icons.print_rounded,
                color: AppTheme.primaryGreen,
                onTap: _printBarcode,
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                label: "Go Back",
                icon: Icons.arrow_back_rounded,
                color: const Color.fromARGB(255, 0, 0, 0),
                textColor: Colors.black87,
                isOutlined: true,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    Color textColor = Colors.white,
    bool isOutlined = false,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: isOutlined ? color : textColor),
        label: Text(
          label,
          style: TextStyle(
            color: isOutlined ? color : textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : color,
          elevation: isOutlined ? 0 : 2,
          side: isOutlined
              ? BorderSide(color: color.withOpacity(0.5))
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
