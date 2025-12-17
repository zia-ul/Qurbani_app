import 'package:flutter/material.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent accidental back navigation without choosing Accept/Decline
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Terms & Conditions"),
          backgroundColor: Colors.green,
          automaticallyImplyLeading: false, // removes default back button
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: const Text(
                      """
• You must be at least 18 years old to book a Qurbani through our App.
• You must provide accurate and complete information when booking.
• Payment must be made in full at the time of booking.
• We accept payment by cash and UPI methods.
• Payment processing fees may apply.
• Animals are allocated based on availability and preference.
• We reserve the right to substitute animals if necessary.
• Specific breeds or sizes are not guaranteed.
• Animals are slaughtered according to Islamic principles and Indian law.
• Meat distribution follows Government of India guidelines.
• We cannot guarantee specific distribution locations or times.
• Refunds are subject to our refund policy.
• Cancellations must be emailed to mubashshira835@gmail.com.
• A cancellation fee may apply.
• We are not liable for losses except negligence or misconduct.
• We are not responsible for booking errors.
• Personal data is processed per IT Act, 2000.
• These terms are governed by Indian law.
• Disputes will be resolved through arbitration.
• We reserve the right to modify these terms anytime.

I confirm that I have read, understood, and agree to the above terms and conditions.
                      """,
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                      ),
                      onPressed: () {
                        Navigator.pop(context, false); // Decline
                      },
                      child: const Text(
                        "Decline",
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () {
                        Navigator.pop(context, true); // Accept
                      },
                      child: const Text("Accept"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
