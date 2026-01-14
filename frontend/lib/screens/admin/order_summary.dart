import 'package:flutter/material.dart';
import 'package:qurbani/theme/theme.dart';

class _SummaryRow extends StatelessWidget {
  final int total, pending, processing, delivered;

  const _SummaryRow({
    required this.total,
    required this.pending,
    required this.processing,
    required this.delivered,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, int value, Color c) => Expanded(
      child: Card(
        color: c.withOpacity(.1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label),
            ],
          ),
        ),
      ),
    );

    return Row(
      children: [
        tile('Total', total, AppTheme.primaryGreen),
        tile('Pending', pending, Colors.orange),
        tile('Processing', processing, Colors.purple),
        tile('Delivered', delivered, AppTheme.primaryGreen),
      ],
    );
  }
}
