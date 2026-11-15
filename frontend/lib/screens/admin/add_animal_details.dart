import 'package:flutter/material.dart';
import 'package:Qurbani/screens/admin/animal_form_screen.dart';

/// Backward-compatible wrapper delegating to the unified AnimalFormScreen.
class AddAnimalPage extends StatelessWidget {
  const AddAnimalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnimalFormScreen();
  }
}