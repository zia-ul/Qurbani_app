import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qurbani/services/order_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qurbani/screens/user/payment_processing_page.dart';

class Shareholder {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController guardianController = TextEditingController();
  String qurbaniDay = 'Day 1';

  void dispose() {
    nameController.dispose();
    guardianController.dispose();
  }
}

class QurbaniOrderPage extends StatefulWidget {
  final String adminId;

  const QurbaniOrderPage({super.key, required this.adminId});

  @override
  State<QurbaniOrderPage> createState() => _QurbaniOrderPageState();
}

class _QurbaniOrderPageState extends State<QurbaniOrderPage> {
  // Theme Colors from HomePage
  final Color primaryGreen = const Color(0xff3D6B4E);
  final Color bgGradientStart = const Color(0xffF2E8D5); 
  final Color bgGradientEnd = const Color(0xffFFFFFF);

  final List<Shareholder> _shareholders = [];
  String _paymentMethod = 'Cash';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addShareholder();
  }

  @override
  void dispose() {
    for (var s in _shareholders) { s.dispose(); }
    super.dispose();
  }

  void _addShareholder() {
    setState(() { _shareholders.add(Shareholder()); });
  }

  void _removeShareholder(int index) {
    setState(() {
      _shareholders[index].dispose();
      _shareholders.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text("Order Details", 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgGradientStart, bgGradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Shareholder Information", 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)),
                  const SizedBox(height: 16),
                  
                  ...List.generate(_shareholders.length, (index) => _shareholderCard(index)),

                  // Add Person Button
                  Center(
                    child: TextButton.icon(
                      onPressed: _addShareholder,
                      icon: Icon(Icons.add_circle_outline, color: primaryGreen),
                      label: Text("Add Another Shareholder", 
                        style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 30),
                  Text("Payment Summary", 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)),
                  const SizedBox(height: 16),
                  
                  _paymentSection(),

                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
            
            // Bottom Sticky Confirm Button
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildBottomBar(),
            ),

            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _shareholderCard(int index) {
    final shareholder = _shareholders[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGreen.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: primaryGreen.withOpacity(0.1),
                radius: 18,
                child: Text("${index + 1}", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
              ),
              if (_shareholders.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  onPressed: () => _removeShareholder(index),
                ),
            ],
          ),
          const SizedBox(height: 15),
          _customTextField(
            controller: shareholder.nameController,
            label: "Full Name of Shareholder",
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 15),
          _customTextField(
            controller: shareholder.guardianController,
            label: "Father / Guardian Name",
            icon: Icons.family_restroom_outlined,
          ),
          const SizedBox(height: 20),
          const Text("Select Qurbani Day", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Day 1', 'Day 2', 'Day 3'].map((day) {
              bool isSelected = shareholder.qurbaniDay == day;
              return ChoiceChip(
                label: Text(day),
                selected: isSelected,
                selectedColor: primaryGreen,
                onSelected: (_) => setState(() => shareholder.qurbaniDay = day),
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                backgroundColor: Colors.grey[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _paymentSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGreen.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _paymentOption("Cash on Delivery", "Cash", Icons.money),
          const Divider(),
          _paymentOption("Online Payment", "Online", Icons.account_balance_wallet_outlined),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: bgGradientStart.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Shares", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${_shareholders.length}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _paymentOption(String title, String value, IconData icon) {
    return RadioListTile<String>(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      secondary: Icon(icon, color: primaryGreen),
      value: value,
      groupValue: _paymentMethod,
      onChanged: (val) => setState(() => _paymentMethod = val!),
      activeColor: primaryGreen,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _customTextField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryGreen, size: 20),
        filled: true,
        fillColor: const Color(0xffF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen)),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          child: const Text("Confirm & Place Order", style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
      ),
    );
  }

  // --- Logic remains the same as your snippet ---
  Future<void> _submitOrder() async {
    for (var s in _shareholders) {
      if (s.nameController.text.trim().isEmpty || s.guardianController.text.trim().isEmpty) {
        Fluttertoast.showToast(msg: "Please fill all fields", backgroundColor: Colors.red);
        return;
      }
    }
    setState(() => _isLoading = true);
    try {
      final shareholdersData = _shareholders.map((s) => {
        'name': s.nameController.text.trim(),
        'guardianName': s.guardianController.text.trim(),
        'qurbaniDay': s.qurbaniDay,
      }).toList();

      if (_paymentMethod == 'Cash') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Confirm Order"),
            content: const Text("Place order with Cash on Delivery?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Confirm")),
            ],
          ),
        );
        if (confirm != true) { setState(() => _isLoading = false); return; }
      }

      final result = await OrderService.placeOrder(
        userId: '',
        adminId: widget.adminId,
        paymentMethod: _paymentMethod,
        shareholders: shareholdersData,
      );

      if (_paymentMethod == 'Online') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentProcessingPage(
          orderId: result['orderId'],
          totalAmount: 1000.0 * _shareholders.length, 
        )));
      } else {
        Fluttertoast.showToast(msg: "Order placed successfully!", backgroundColor: Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e", backgroundColor: Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }
}