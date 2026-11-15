import 'package:flutter/material.dart';
import 'package:Qurbani/screens/admin/animal_form_screen.dart';

/// Backward-compatible wrapper delegating to the unified AnimalFormScreen.
class AnimalEditPage extends StatelessWidget {
  final String animalId;
  final String orderId;

  const AnimalEditPage({
    super.key,
    required this.animalId,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return AnimalFormScreen(
      animalId: animalId,
      orderId: orderId,
    );
  }
}
