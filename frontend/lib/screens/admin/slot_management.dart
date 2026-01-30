import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  /// 🔴 CHANGE THIS
  static final String? _baseUrl = dotenv.env['BASE_URL'];

  final Color scaffoldBg = const Color(0xffF4F7F4);
  final Color accentGold = const Color(0xffD1C4A9);

  @override
  void initState() {
    super.initState();
    loadSlots();
  }

  String get dayKey => selectedDay.toLowerCase().replaceAll(" ", "");

  // ================= LOAD =================
  Future<void> loadSlots() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse("$_baseUrl/slots/${widget.adminId}/$dayKey"),
      );

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        slots = data
            .map(
              (e) => {
                "time": e["slot_time"],
                "status": e["status"],
                "slot_order": e["slot_order"],
              },
            )
            .toList();
        _sortSlots();
      } else {
        slots = [];
      }
    } catch (e) {
      ToastUtils.showError("Failed to load slots");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ================= SAVE =================
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
      final res = await http.post(
        Uri.parse("$_baseUrl/slots/${widget.adminId}/$dayKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"slots": slots}),
      );

      if (res.statusCode == 200) {
        Fluttertoast.showToast(
          msg: "Saved slots for $selectedDay",
          backgroundColor: AppTheme.primaryGreen,
          textColor: AppTheme.bgGradientEnd,
        );
      } else {
        ToastUtils.showError("Failed to save slots");
      }
    } catch (e) {
      ToastUtils.showError("Server error");
    } finally {
      setState(() => isSaving = false);
    }
  }

  // ================= SLOT LOGIC =================
  void addSlot() {
    setState(() {
      slots.add({"time": "", "status": "Free", "slot_order": slots.length + 1});
    });
  }

  void removeSlot(int index) => setState(() => slots.removeAt(index));

  Future<void> pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      final formatted = picked.format(context);
      if (slots.any((s) => s["time"] == formatted && s != slots[index])) {
        ToastUtils.showError("This time already exists");
        return;
      }

      setState(() {
        slots[index]["time"] = formatted;
        _sortSlots();
      });
    }
  }

  void _sortSlots() {
    slots.sort(
      (a, b) => _toMinutes(a["time"]).compareTo(_toMinutes(b["time"])),
    );
    for (int i = 0; i < slots.length; i++) {
      slots[i]["slot_order"] = i + 1;
    }
  }

  int _toMinutes(String time) {
    if (time.isEmpty) return 99999;
    final m = RegExp(r'(\d+):(\d+)\s?(AM|PM)').firstMatch(time);
    if (m == null) return 99999;
    int h = int.parse(m.group(1)!);
    int min = int.parse(m.group(2)!);
    if (m.group(3) == "PM" && h != 12) h += 12;
    if (m.group(3) == "AM" && h == 12) h = 0;
    return h * 60 + min;
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("Manage Eid Slots"),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.bgGradientEnd,
      ),
      body: Column(
        children: [
          _buildHeaderActions(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : slots.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: slots.length,
                    itemBuilder: (_, i) => _buildSlotCard(i),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField(
              value: selectedDay,
              items: [
                "Day 1",
                "Day 2",
                "Day 3",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                selectedDay = v!;
                loadSlots();
              },
            ),
          ),
          const SizedBox(width: 8),
          _btn(Icons.add, "Add", addSlot, Colors.orange),
          const SizedBox(width: 8),
          _btn(
            Icons.save,
            "Save",
            saveSlots,
            AppTheme.primaryGreen,
            loading: isSaving,
          ),
        ],
      ),
    );
  }

  Widget _btn(
    IconData icon,
    String label,
    VoidCallback onTap,
    Color color, {
    bool loading = false,
  }) {
    return ElevatedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(),
            )
          : Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(backgroundColor: color),
    );
  }

  Widget _buildSlotCard(int index) {
    final slot = slots[index];
    final booked = slot["status"] != "Free";

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text("${index + 1}")),
        title: GestureDetector(
          onTap: booked ? null : () => pickTime(index),
          child: Text(slot["time"].isEmpty ? "Select Time" : slot["time"]),
        ),
        subtitle: Text(
          slot["status"],
          style: TextStyle(
            color: booked ? AppTheme.warningRed : AppTheme.primaryGreen,
          ),
        ),
        trailing: booked
            ? const Icon(Icons.lock)
            : IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => removeSlot(index),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text("No slots added"));
  }
}
