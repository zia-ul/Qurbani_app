import 'package:Qurbani/services/admin_order_service.dart';
import 'package:flutter/material.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';

class AdminShareSetupPage extends StatefulWidget {
  const AdminShareSetupPage({super.key});

  @override
  State<AdminShareSetupPage> createState() => _AdminShareSetupPageState();
}

class _AdminShareSetupPageState extends State<AdminShareSetupPage> {
  final _formKey = GlobalKey<FormState>();

  final totalSharesController = TextEditingController();
  final pricePerShareController = TextEditingController();
  final lateBookingFeeController = TextEditingController();
  final lastBookingDateController = TextEditingController();
  final deliveryFeeController = TextEditingController();
  final deliveryThresholdController = TextEditingController();
  final dayOneLimit = TextEditingController();
  final dayTwoLimit = TextEditingController();
  final dayThreeLimit = TextEditingController();

  bool isDeliveryPaid = false;
  bool isLoading = false;
  DateTime? lastBookingDate;

  @override
  void initState() {
    super.initState();
    fetchExistingSetup();
  }

  @override
  void dispose() {
    totalSharesController.dispose();
    pricePerShareController.dispose();
    lateBookingFeeController.dispose();
    lastBookingDateController.dispose();
    deliveryFeeController.dispose();
    deliveryThresholdController.dispose();
    dayOneLimit.dispose();
    dayTwoLimit.dispose();
    dayThreeLimit.dispose();
    super.dispose();
  }

  Future<void> fetchExistingSetup() async {
    setState(() => isLoading = true);

    try {
      final data = await AdminOrderService.getShareSetup();

      if (!mounted) return;

      if (data != null) {
        setState(() {
          /// --- Numbers ---
          totalSharesController.text = (data['totalShares'] ?? '').toString();

          pricePerShareController.text = (data['pricePerShare'] ?? '')
              .toString();
          lateBookingFeeController.text = (data['lateBookingFee'] ?? '')
              .toString();

          /// --- Date ---
          if (data['lastBookingDate'] != null) {
            lastBookingDate = DateTime.parse(data['lastBookingDate']).toLocal();

            lastBookingDateController.text =
                "${lastBookingDate!.year}-"
                "${lastBookingDate!.month.toString().padLeft(2, '0')}-"
                "${lastBookingDate!.day.toString().padLeft(2, '0')}";
          }

          /// --- Delivery ---
          isDeliveryPaid = data['deliveryType'] == "paid";

          deliveryFeeController.text = isDeliveryPaid
              ? (data['deliveryFee'] ?? '').toString()
              : '';
          deliveryThresholdController.text =
              data['deliveryThreshold']?.toString() ?? '';
              dayOneLimit.text = (data['dayOneLimit'] ?? '').toString();
          dayTwoLimit.text = (data['dayTwoLimit'] ?? '').toString();
          dayThreeLimit.text = (data['dayThreeLimit'] ?? '').toString();
        });
      }
    } catch (e, stack) {
      print("ERROR FETCHING: $e");
      AppLogger.error("Failed to fetch share setup", e, stack);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> pickLastBookingDate() async {
    try {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year, 1, 1),
        lastDate: DateTime(now.year, 12, 31),
      );

      if (picked != null) {
        setState(() {
          lastBookingDate = picked;
          lastBookingDateController.text =
              "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        });
      }
    } catch (e, stack) {
      AppLogger.error("Error picking last booking date", e, stack);
      ToastUtils.showError("Failed to pick date");
    }
  }

  Future<void> submitSetup() async {
    if (!_formKey.currentState!.validate()) return;

    if (lastBookingDate == null) {
      ToastUtils.showError("Please select the last booking date");
      return;
    }

    setState(() => isLoading = true);

    try {
      final payload = {
        "totalShares": int.parse(totalSharesController.text.trim()),
        "pricePerShare": double.parse(pricePerShareController.text.trim()),
        "lateBookingFee": lateBookingFeeController.text.trim().isNotEmpty
            ? double.parse(lateBookingFeeController.text.trim())
            : 0,
        "lastBookingDate": lastBookingDate!.toIso8601String(),
        "deliveryType": isDeliveryPaid ? "paid" : "free",
        "deliveryFee":
            isDeliveryPaid && deliveryFeeController.text.trim().isNotEmpty
            ? double.parse(deliveryFeeController.text.trim())
            : 0,
        "deliveryThreshold":
            isDeliveryPaid && deliveryThresholdController.text.trim().isNotEmpty
            ? double.parse(deliveryThresholdController.text.trim())
            : null,
        "dayOneLimit": double.parse(dayOneLimit.text.trim()),
        "dayTwoLimit": double.parse(dayTwoLimit.text.trim()),
        "dayThreeLimit": double.parse(dayThreeLimit.text.trim()),
      };

      AppLogger.info("Saving admin share setup");

      await AdminOrderService.saveShareSetup(payload);

      ToastUtils.showSuccess("Share setup saved successfully");
      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      AppLogger.error("Failed to save admin share setup", e, stack);
      ToastUtils.showError(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text("Admin Share Setup"),
        centerTitle: true,
        backgroundColor: AppTheme.bgGradientEnd,
        foregroundColor: AppTheme.primaryGreen,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _card([
                      _label("Total Shares", required: true),
                      TextFormField(
                        controller: totalSharesController,
                        keyboardType: TextInputType.number,
                        decoration: _decoration("Enter total shares"),
                        validator: (v) =>
                            v == null || v.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 15),
                      _label("Price per Share", required: true),
                      TextFormField(
                        controller: pricePerShareController,
                        keyboardType: TextInputType.number,
                        decoration: _decoration(
                          "Enter price per share",
                        ).copyWith(prefixText: "₹ "),
                        validator: (v) =>
                            v == null || v.isEmpty ? "Required" : null,
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _card([
                      _label("Last Booking Date", required: true),
                      TextFormField(
                        controller: lastBookingDateController,
                        readOnly: true,
                        decoration: _decoration("Select date").copyWith(
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        onTap: pickLastBookingDate,
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _card([
                      _label("Late Booking Fee (Optional)"),
                      TextFormField(
                        controller: lateBookingFeeController,
                        keyboardType: TextInputType.number,
                        decoration: _decoration(
                          "Additional fee for late bookings",
                        ).copyWith(prefixText: "₹ "),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // Qurbani day wise limit
                    _card([
                      _label("Day 1 Limit"),
                      TextFormField(
                        controller: dayOneLimit,
                        keyboardType: TextInputType.number,
                        // decoration: _decoration(
                        //   "Additional fee for late bookings",
                        // ).copyWith(prefixText: "₹ "),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _card([
                      _label("Day 2 Limit"),
                      TextFormField(
                        controller: dayTwoLimit,
                        keyboardType: TextInputType.number,
                        // decoration: _decoration(
                        //   "Additional fee for late bookings",
                        // ).copyWith(prefixText: "₹ "),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _card([
                      _label("Day 3 Limit"),
                      TextFormField(
                        controller: dayThreeLimit,
                        keyboardType: TextInputType.number,
                        // decoration: _decoration(
                        //   "Additional fee for late bookings",
                        // ).copyWith(prefixText: "₹ "),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    _card([
                      _label("Delivery Setup"),
                      SwitchListTile(
                        value: isDeliveryPaid,
                        onChanged: (v) => setState(() => isDeliveryPaid = v),
                        title: Text(
                          isDeliveryPaid ? "Paid Delivery" : "Free Delivery",
                        ),
                        activeColor: AppTheme.primaryGreen,
                      ),
                      if (isDeliveryPaid) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: deliveryFeeController,
                          keyboardType: TextInputType.number,
                          decoration: _decoration("Delivery fee"),
                          validator: (v) =>
                              isDeliveryPaid && (v == null || v.isEmpty)
                              ? "Required"
                              : null,
                        ),
                        // const SizedBox(height: 10),
                        // TextFormField(
                        //   controller: deliveryThresholdController,
                        //   keyboardType: TextInputType.number,
                        //   decoration: _decoration(
                        //     "Free delivery threshold (optional)",
                        //   ),
                        // ),
                      ],
                    ]),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: submitSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                        ),
                        child: const Text(
                          "Save Setup",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.bgGradientEnd,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
        children: required
            ? const [
                TextSpan(
                  text: " *",
                  style: TextStyle(color: AppTheme.warningRed),
                ),
              ]
            : [],
      ),
    ),
  );

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.grey[50],
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  );
}
