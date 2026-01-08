import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qurbani/services/order_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  final Color primaryGreen = const Color(0xff3D6B4E);
  final List<Shareholder> _shareholders = [];
  final _storage = const FlutterSecureStorage();

  String _paymentMethod = 'Cash';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addShareholder(); // start with one person
  }

  @override
  void dispose() {
    for (var s in _shareholders) {
      s.dispose();
    }
    super.dispose();
  }

  void _addShareholder() {
    setState(() {
      _shareholders.add(Shareholder());
    });
  }

  void _removeShareholder(int index) {
    setState(() {
      _shareholders[index].dispose();
      _shareholders.removeAt(index);
    });
  }

  int get totalShares => _shareholders.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      appBar: AppBar(
        title: const Text("Place Your Qurbani Order"),
        backgroundColor: primaryGreen,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                /// SHAREHOLDER CARDS
                ...List.generate(_shareholders.length, (index) {
                  return _shareholderCard(index);
                }),

                const SizedBox(height: 16),

                /// ADD BUTTON
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add Another Person"),
                    onPressed: _addShareholder,
                  ),
                ),

                const SizedBox(height: 24),

                /// PAYMENT
                _buildSectionCard(
                  title: "Payment Method",
                  icon: Icons.payment,
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text("Cash on Delivery"),
                        value: "Cash",
                        groupValue: _paymentMethod,
                        onChanged: (val) => setState(() => _paymentMethod = val!),
                        activeColor: primaryGreen,
                      ),
                      RadioListTile<String>(
                        title: const Text("Online Payment"),
                        value: "Online",
                        groupValue: _paymentMethod,
                        onChanged: (val) => setState(() => _paymentMethod = val!),
                        activeColor: primaryGreen,
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Total Shares",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "$totalShares",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                /// SUBMIT
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                    child: const Text(
                      "Confirm & Place Order",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  /// SHAREHOLDER CARD
  Widget _shareholderCard(int index) {
    final shareholder = _shareholders[index];

    return _buildSectionCard(
      title: "Shareholder ${index + 1}",
      icon: Icons.person,
      child: Column(
        children: [
          TextField(
            controller: shareholder.nameController,
            decoration: const InputDecoration(labelText: "Shareholder Name"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: shareholder.guardianController,
            decoration: const InputDecoration(
              labelText: "Father's / Mother's Name",
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Day 1', 'Day 2', 'Day 3'].map((day) {
              return ChoiceChip(
                label: Text(day),
                selected: shareholder.qurbaniDay == day,
                selectedColor: primaryGreen,
                labelStyle: TextStyle(
                  color: shareholder.qurbaniDay == day ? Colors.white : Colors.black,
                ),
                onSelected: (_) {
                  setState(() {
                    shareholder.qurbaniDay = day;
                  });
                },
              );
            }).toList(),
          ),
          if (_shareholders.length > 1)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  "Remove",
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () => _removeShareholder(index),
              ),
            ),
        ],
      ),
    );
  }

  /// COMMON CARD
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryGreen),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  /// SUBMIT ORDER USING NODE + MYSQL
  Future<void> _submitOrder() async {
    // Validation
    for (var s in _shareholders) {
      if (s.nameController.text.trim().isEmpty ||
          s.guardianController.text.trim().isEmpty) {
        Fluttertoast.showToast(
          msg: "Please fill all fields",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Get userId from secure storage (stored during login)
      final userId = await _storage.read(key: 'userId');
      if (userId == null) throw Exception('User not authenticated');

      // Prepare shareholders data
      final shareholdersData = _shareholders.map((s) {
        return {
          'name': s.nameController.text.trim(),
          'guardianName': s.guardianController.text.trim(),
          'qurbaniDay': s.qurbaniDay,
        };
      }).toList();

      // Place order via backend API
      await OrderService.placeOrder(
        userId: userId,
        adminId: widget.adminId,
        paymentMethod: _paymentMethod,
        shareholders: shareholdersData,
      );

      Fluttertoast.showToast(
        msg: "Order placed successfully",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error placing order: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
