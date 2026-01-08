import 'package:flutter/material.dart';

// ignore: unused_element
class _FilterBar extends StatelessWidget {
  final String processingFilter;
  final String deliveryFilter;
  final Function(String) onProcessingChanged;
  final Function(String) onDeliveryChanged;
  final Function(DateTime?, DateTime?) onDatePick;

  const _FilterBar({
    required this.processingFilter,
    required this.deliveryFilter,
    required this.onProcessingChanged,
    required this.onDeliveryChanged,
    required this.onDatePick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField(
              initialValue: processingFilter,
              items: [
                'All',
                'Pending',
                'Processing',
                'Completed',
                'Cancelled',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => onProcessingChanged(v!),
              decoration: const InputDecoration(labelText: 'Processing'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField(
              initialValue: deliveryFilter,
              items: [
                'All',
                'Pending',
                'Out for Delivery',
                'Delivered',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => onDeliveryChanged(v!),
              decoration: const InputDecoration(labelText: 'Delivery'),
            ),
          ),
        ],
      ),
    );
  }
}
