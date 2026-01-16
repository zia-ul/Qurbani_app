import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';

class AdminSlotPage extends StatefulWidget {
  final String adminId;
  const AdminSlotPage({required this.adminId, super.key});

  @override
  State<AdminSlotPage> createState() => _AdminSlotPageState();
}

class _AdminSlotPageState extends State<AdminSlotPage> {
  String selectedDay = "Day 1";
  List<Map<String, dynamic>> slots = [];
  bool isLoading = false;
  bool isSaving = false;

  // Theme Constants
  final Color scaffoldBg = const Color(0xffF4F7F4);
  final Color accentGold = const Color(0xffD1C4A9);

  @override
  void initState() {
    super.initState();
    loadSlots();
  }

  Future<void> loadSlots() async {
    setState(() => isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection("eidSlots")
          .doc(widget.adminId)
          .get();

      if (doc.exists && doc.data()![selectedDay.toLowerCase()] != null) {
        setState(() {
          slots = List<Map<String, dynamic>>.from(
            doc.data()![selectedDay.toLowerCase()],
          );
          _sortSlots();
        });
      } else {
        setState(() => slots = []);
      }
    } catch (e) {
      ToastUtils.showError("Error loading slots: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _sortSlots() {
    slots.sort(
      (a, b) => _toMinutes(a["time"]).compareTo(_toMinutes(b["time"])),
    );
  }

  void addSlot() {
    setState(() {
      slots.add({"time": "", "status": "Free"});
    });
  }

  void removeSlot(int index) => setState(() => slots.removeAt(index));

  Future<void> pickTime(int index) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      String formatted = picked.format(context);
      bool exists = slots.any(
        (s) => s["time"] == formatted && s != slots[index],
      );

      if (exists) {
        ToastUtils.showError("This time already exists!");
        return;
      }

      setState(() {
        slots[index]["time"] = formatted;
        _sortSlots();
      });
    }
  }

  Future<void> saveSlots() async {
    if (slots.isEmpty) {
      ToastUtils.showError("Please add at least one slot");
      return;
    }

    if (slots.any((s) => s["time"].toString().isEmpty)) {
      ToastUtils.showError("Please set time for all slots");
      return;
    }

    setState(() => isSaving = true);
    _sortSlots();

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Save in eidSlots
      batch.set(
        FirebaseFirestore.instance.collection("eidSlots").doc(widget.adminId),
        {selectedDay.toLowerCase(): slots},
        SetOptions(merge: true),
      );

      // 2. Save in admin's users document
      batch.set(
        FirebaseFirestore.instance.collection("users").doc(widget.adminId),
        {
          "usersSlots": {selectedDay.toLowerCase(): slots},
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // 3. Update Animals (Run separately to handle large counts)
      final animalsSnapshot = await FirebaseFirestore.instance
          .collection("animals")
          .where("adminId", isEqualTo: widget.adminId)
          .get();

      for (var doc in animalsSnapshot.docs) {
        doc.reference.set({
          "adminSlots": {selectedDay.toLowerCase(): slots},
        }, SetOptions(merge: true));
      }

      // _showSnackBar("Saved slots for $selectedDay", primaryGreen);

      Fluttertoast.showToast(
        msg: "Saved slots for $selectedDay",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.primaryGreen,
        textColor: Colors.white,
      );
    } catch (e) {
      // _showSnackBar("Failed to save slots: $e", Colors.red);
      ToastUtils.showError("Failed to save slots: $e");
    } finally {
      setState(() => isSaving = false);
    }
  }

  // void _showSnackBar(String message, Color color) {

  //   ToastUtils.showSuccess(message);
  //   ScaffoldMessenger.of(
  //     context,
  //   ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  // }

  int _toMinutes(String time) {
    if (time.isEmpty) return 99999;
    final reg = RegExp(r'(\d+):(\d+)\s?(AM|PM)');
    final m = reg.firstMatch(time);
    if (m == null) return 99999;
    int h = int.parse(m.group(1)!);
    int min = int.parse(m.group(2)!);
    String p = m.group(3)!;
    if (p == "PM" && h != 12) h += 12;
    if (p == "AM" && h == 12) h = 0;
    return h * 60 + min;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text(
          "Manage Eid Slots",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF9F4F1), Color(0xFFF2E8D5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            _buildHeaderActions(),
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : slots.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: slots.length,
                      itemBuilder: (context, index) => _buildSlotCard(index),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accentGold.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedDay,
              isDense: true,
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                labelText: "Day",
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: [
                "Day 1",
                "Day 2",
                "Day 3",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                setState(() => selectedDay = v!);
                loadSlots();
              },
            ),
          ),
          const SizedBox(width: 8),
          _actionIconButton(Icons.add, "Add", () => addSlot(), Colors.orange),
          const SizedBox(width: 8),
          _actionIconButton(
            Icons.save,
            "Save",
            () => saveSlots(),
            AppTheme.primaryGreen,
            isLoading: isSaving,
          ),
        ],
      ),
    );
  }

  Widget _actionIconButton(
    IconData icon,
    String label,
    VoidCallback onTap,
    Color color, {
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSlotCard(int index) {
    final slot = slots[index];
    final bool isBooked = slot["status"] != "Free";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBooked ? Colors.red.shade200 : accentGold.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isBooked ? Colors.red : AppTheme.primaryGreen,
          child: Text(
            "${index + 1}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: GestureDetector(
          onTap: isBooked ? null : () => pickTime(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scaffoldBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  slot["time"].isEmpty ? "Select Time" : slot["time"],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: slot["time"].isEmpty
                        ? AppTheme.primaryGreen
                        : Colors.black,
                  ),
                ),
                const Icon(
                  Icons.access_time,
                  size: 18,
                  color: AppTheme.primaryGreen,
                ),
              ],
            ),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            slot["status"].toUpperCase(),
            style: TextStyle(
              color: isBooked ? Colors.red : AppTheme.primaryGreen,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        trailing: isBooked
            ? const Icon(Icons.lock, color: Colors.redAccent)
            : IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => removeSlot(index),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: accentGold),
          const SizedBox(height: 16),
          const Text(
            "No slots added for this day",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Click 'Add' to create your first Qurbani slot",
            style: TextStyle(color: AppTheme.primaryGreen),
          ),
        ],
      ),
    );
  }
}
