import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class GenerateStickersPage extends StatefulWidget {
  const GenerateStickersPage({super.key});

  @override
  State<GenerateStickersPage> createState() => _GenerateStickersPageState();
}

class _GenerateStickersPageState extends State<GenerateStickersPage> {
  final animalTypes = ["Goat", "Buffalo"];
  String selectedAnimal = "Goat";
  final TextEditingController qtyController = TextEditingController();
  List<String> generatedBarcodes = [];

  // Generate barcode IDs
  void generateBarcodes() {
    final qty = int.tryParse(qtyController.text) ?? 0;
    List<String> barcodes = [];
    for (int i = 1; i <= qty; i++) {
      barcodes.add(
        "${selectedAnimal.toUpperCase()}-${i.toString().padLeft(3, '0')}",
      );
    }
    setState(() {
      generatedBarcodes = barcodes;
    });
  }

  // Print all generated barcodes as PDF
  void printBarcodes() async {
    if (generatedBarcodes.isEmpty) return;

    final pdf = pw.Document();

    final bc = Barcode.code128();

    for (var barcodeId in generatedBarcodes) {
      pdf.addPage(
        pw.Page(
          build: (context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    barcodeId,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.BarcodeWidget(
                    barcode: bc,
                    data: barcodeId,
                    width: 200,
                    height: 80,
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Generate Stickers")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField(
              items: animalTypes
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              initialValue: selectedAnimal,
              onChanged: (value) {
                setState(() {
                  selectedAnimal = value.toString();
                });
              },
              decoration: const InputDecoration(labelText: "Select Animal"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Number of Animals"),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: generateBarcodes,
                    child: const Text("Generate Barcodes"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: printBarcodes,
                    child: const Text("Print All Barcodes"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: generatedBarcodes.length,
                itemBuilder: (context, index) {
                  final barcodeId = generatedBarcodes[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            barcodeId,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          BarcodeWidget(
                            barcode: Barcode.code128(),
                            data: barcodeId,
                            width: 200,
                            height: 80,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
