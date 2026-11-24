import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Qurbani/screens/admin/animal_form_screen.dart';

void main() {
  tearDown(() {
    AnimalFormScreen.mockLoadDetails = null;
  });

  testWidgets('AnimalFormScreen renders Create Mode with empty fields and shares input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AnimalFormScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Create Mode Button
    expect(find.text('Add Animal'), findsNWidgets(2)); // AppBar title & Submit button text
    expect(find.textContaining('Animal Type'), findsWidgets);
    expect(find.textContaining('Animal Breed'), findsWidgets);
    expect(find.textContaining('Shares Available'), findsOneWidget);
    expect(find.textContaining('Animal Barcode'), findsNothing); // Barcode is edit-only
  });

  testWidgets('AnimalFormScreen renders Edit Mode with Barcode section and Update button', (
    WidgetTester tester,
  ) async {
    AnimalFormScreen.mockLoadDetails = (animalId, orderId) async {
      return {
        'animal_type': 'Goat',
        'breed': 'Sahiwal',
        'details_description': 'Healthy and active',
        'details_age': '2 Years',
        'details_height': '3 ft',
        'details_weight': '45',
        'shares': 1,
        'barcode': 'ANM-998877',
        'photo_urls': <String>[],
      };
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: AnimalFormScreen(
          animalId: 'test-animal-123',
          orderId: 'test-order-456',
        ),
      ),
    );

    // Let mock loader finish
    await tester.pumpAndSettle();

    // Verify Title & Edit Mode Button
    expect(find.text('Edit Animal Details'), findsOneWidget);
    expect(find.text('Update Animal Details'), findsOneWidget);
    expect(find.textContaining('Animal Barcode'), findsOneWidget);
    expect(find.textContaining('Shares Available'), findsNothing); // Shares is create-only
  });
}
