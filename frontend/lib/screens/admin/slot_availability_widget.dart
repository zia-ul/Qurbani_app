import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'slot_management.dart';
import 'package:Qurbani/theme/theme.dart';

class SlotAvailabilityWidget extends StatelessWidget {
  final String adminId;

  const SlotAvailabilityWidget({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("eidSlots")
          .doc(adminId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildEmptyState(context);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final days = ["day 1", "day 2", "day 3"];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Slot Availability",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index];
                  final slots = data[day] ?? [];
                  final total = slots.length;
                  final free = slots.where((s) => s["status"] == "Free").length;
                  final booked = total - free;

                  return Container(
                    width: MediaQuery.of(context).size.width * 0.65,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgGradientEnd,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: AppTheme.primaryGreen,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatRow("Total Slots", total.toString()),
                        _buildStatRow(
                          "Available",
                          free.toString(),
                          color: AppTheme.primaryGreen,
                        ),
                        _buildStatRow(
                          "Booked",
                          booked.toString(),
                          color: AppTheme.warningRed,
                        ),
                        const Spacer(),
                        if (total > 0)
                          LinearProgressIndicator(
                            value: total > 0 ? booked / total : 0,
                            backgroundColor: Colors.grey.shade200,
                            color: AppTheme.primaryGreen,
                            minHeight: 6,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.primaryGreen),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Card(
        color: AppTheme.bgGradientEnd,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: AppTheme.primaryGreen, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Slot Availability",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "No slots configured yet. Please set up your Eid slots to start accepting bookings.",
                style: TextStyle(fontSize: 14, color: AppTheme.primaryGreen),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to slot management
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminSlotPage(adminId: adminId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text("Set Up Slots"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
