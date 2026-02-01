import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQs'),
        backgroundColor: const Color(0xff3D6B4E),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          _FaqTile(
            question: 'What is Qurbani?',
            answer:
                'Qurbani is the ritual sacrifice of an animal performed during Eid al-Adha to fulfill a religious obligation.',
          ),
          _FaqTile(
            question: 'Which animals are allowed for Qurbani?',
            answer:
                'Goat, sheep, cow, buffalo, and camel are allowed provided they meet age and health requirements.',
          ),
          _FaqTile(
            question: 'Can I share one animal with others?',
            answer:
                'Yes. A cow, buffalo, or camel can be shared by up to 7 people. Goat and sheep cannot be shared.',
          ),
          _FaqTile(
            question: 'How do I place a Qurbani order?',
            answer:
                'Select your animal, choose quantity, proceed to checkout, and complete payment through the app.',
          ),
          _FaqTile(
            question: 'What payment methods are supported?',
            answer:
                'We support online payments as well as cash payments depending on availability.',
          ),
          _FaqTile(
            question: 'Is cash payment allowed?',
            answer:
                'Yes. If you choose cash payment, the payment ID will remain empty until payment is collected.',
          ),
          _FaqTile(
            question: 'Can I track my Qurbani order?',
            answer:
                'Yes. You can track your order status from the Orders section of the app.',
          ),
          _FaqTile(
            question: 'Will I receive proof of Qurbani?',
            answer:
                'Yes. Images or confirmation details will be provided after the Qurbani is completed.',
          ),
          _FaqTile(
            question: 'What if my payment fails?',
            answer:
                'If payment fails, you can retry or choose another payment method from the checkout screen.',
          ),
          _FaqTile(
            question: 'Who can I contact for support?',
            answer:
                'You can contact our support team from the Help or Contact Us section inside the app.',
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
