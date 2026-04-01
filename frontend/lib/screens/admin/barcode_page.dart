import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Qurbani/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import 'package:Qurbani/theme/theme.dart';

class BarcodePage extends StatefulWidget {
  final String barcodeValue;

  const BarcodePage({super.key, required this.barcodeValue});

  @override
  State<BarcodePage> createState() => _BarcodePageState();
}

class _BarcodePageState extends State<BarcodePage> {
  final GlobalKey _globalKey = GlobalKey();
  final _storage = const FlutterSecureStorage();

  final Color bgParchment = const Color(0xffF2E8D5);
  bool _isHandlingScan = false;

  String get displayBarcode {
    if (widget.barcodeValue.length > 12) {
      return widget.barcodeValue.substring(widget.barcodeValue.length - 12);
    }
    return widget.barcodeValue;
  }

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
                  "ID: $displayBarcode",
                  style: const pw.TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _fetchAnimalByBarcode(String barcode) async {
    final token = await _storage.read(key: 'token');
    if (token == null) {
      throw const ApiException("Not authenticated");
    }

    final response = await ApiClient.get(
      ApiClient.uri('animals/barcode/$barcode'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return ApiClient.decodeMap(
        response,
        fallbackMessage: "Unable to load barcode details right now.",
      );
    } else {
      throw ApiException(
        ApiClient.errorMessage(
          response,
          fallbackMessage: "Unable to load barcode details right now.",
        ),
        statusCode: response.statusCode,
      );
    }
  }

  void _scanBarcode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text("Scan Animal Barcode"),
            backgroundColor: AppTheme.primaryGreen,
          ),
          body: MobileScanner(
            onDetect: (capture) async {
              if (_isHandlingScan) return;

              final barcode = capture.barcodes.first.rawValue?.trim();
              if (barcode == null || barcode.isEmpty) return;
              _isHandlingScan = true;

              Navigator.pop(context);

              try {
                final data = await _fetchAnimalByBarcode(barcode);
                if (!mounted) return;
                _showAnimalDetailsDialog(data);
              } catch (e) {
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Error"),
                    content: Text(
                      _friendlyErrorMessage(
                        e,
                        fallback: "Unable to load barcode details right now.",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close"),
                      ),
                    ],
                  ),
                );
              } finally {
                _isHandlingScan = false;
              }
            },
          ),
        ),
      ),
    );
  }

  String _friendlyErrorMessage(Object error, {required String fallback}) {
    if (error is ApiException) {
      return error.message;
    }

    final cleaned = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .trim();

    return cleaned.isEmpty ? fallback : cleaned;
  }

  String _formatQurbaniDay(dynamic value) {
    switch (value?.toString()) {
      case 'day_1':
      case 'Day 1':
        return 'Day 1';
      case 'day_2':
      case 'Day 2':
        return 'Day 2';
      case 'day_3':
      case 'Day 3':
        return 'Day 3';
      default:
        return 'N/A';
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return 'N/A';

    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  String _formatAddress(dynamic rawAddress) {
    if (rawAddress == null || rawAddress.toString().trim().isEmpty) {
      return 'N/A';
    }

    try {
      final decoded = jsonDecode(rawAddress.toString());

      final country = decoded['country']?.toString() ?? '';
      final state = decoded['state']?.toString() ?? '';
      final city = decoded['city']?.toString() ?? '';
      final addressLine =
          decoded['address_line']?.toString() ??
          decoded['street']?.toString() ??
          '';

      return [
        addressLine,
        city,
        state,
        country,
      ].where((e) => e.isNotEmpty).join(', ');
    } catch (_) {
      return rawAddress.toString();
    }
  }

  Widget _infoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 95,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showAnimalDetailsDialog(Map<String, dynamic> data) {
    final animal = Map<String, dynamic>.from(data['animal'] ?? {});
    final List<dynamic> shareholdersRaw = data['shareholders'] is List
        ? data['shareholders'] as List<dynamic>
        : [];

    final shareholders = shareholdersRaw
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Animal & Shareholder Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Animal Information",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow(
                  "Animal #",
                  animal['id']?.toString() ??
                      animal['animal_id']?.toString() ??
                      'N/A',
                  icon: Icons.tag,
                ),
                _infoRow(
                  "Type",
                  animal['animal_type']?.toString() ?? 'N/A',
                  icon: Icons.pets,
                ),
                _infoRow(
                  "Barcode",
                  animal['barcode']?.toString() ?? 'N/A',
                  icon: Icons.qr_code,
                ),
                _infoRow(
                  "Day",
                  _formatQurbaniDay(animal['qurbani_day']),
                  icon: Icons.calendar_today,
                ),
                _infoRow(
                  "Time",
                  _formatDateTime(animal['qurbani_datetime']),
                  icon: Icons.access_time,
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                const Text(
                  "Assigned Shareholders",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 12),

                if (shareholders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text("No shareholders assigned yet."),
                  )
                else
                  ...shareholders.map((shareholder) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shareholder['shareholder_name']?.toString() ??
                                'N/A',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _infoRow(
                            "Guardian",
                            shareholder['guardian_name']?.toString() ?? 'N/A',
                            icon: Icons.person_outline,
                          ),
                          _infoRow(
                            "Share #",
                            shareholder['share_number']?.toString() ?? 'N/A',
                            icon: Icons.confirmation_number_outlined,
                          ),
                          _infoRow(
                            "Contact",
                            shareholder['contact_no']?.toString() ?? 'N/A',
                            icon: Icons.phone,
                          ),
                          _infoRow(
                            "Address",
                            _formatAddress(shareholder['address']),
                            icon: Icons.location_on_outlined,
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    Color textColor = AppTheme.bgGradientEnd,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgParchment,
      appBar: AppBar(
        title: const Text(
          "Animal Identification",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.bgGradientEnd,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.bgGradientEnd),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.bgGradientEnd,
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

              RepaintBoundary(
                key: _globalKey,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bgGradientEnd,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryGreen.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      bw.BarcodeWidget(
                        barcode: bw.Barcode.code128(),
                        data: widget.barcodeValue,
                        width: double.infinity,
                        height: 140,
                        drawText: false,
                        padding: const EdgeInsets.all(10),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        displayBarcode,
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

              _buildActionButton(
                label: "Print Identification Tag",
                icon: Icons.print_rounded,
                color: AppTheme.primaryGreen,
                onTap: _printBarcode,
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                label: "Scan Barcode",
                icon: Icons.qr_code_scanner,
                color: Colors.orange,
                onTap: _scanBarcode,
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                label: "Go Back",
                icon: Icons.arrow_back_rounded,
                color: Colors.black,
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
}
