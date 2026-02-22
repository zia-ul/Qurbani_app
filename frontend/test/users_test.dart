import 'package:Qurbani/screens/user/marketplace.dart';
import 'package:Qurbani/screens/user/rate_order.dart';
import 'package:Qurbani/screens/user/reset_password_page.dart';
import 'package:Qurbani/screens/user/user_home_screen.dart';
import 'package:Qurbani/screens/user/user_special_request.dart';
import 'package:Qurbani/services/auth_service.dart';
import 'package:Qurbani/services/ratings_service.dart';
import 'package:Qurbani/services/request_service.dart';
import 'package:Qurbani/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  // User Home Page
  testWidgets('HomePage loads user name and main actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(id: 'test-user-id', name: 'Ali', role: 'user'),
      ),
    );

    // Let UI settle
    await tester.pumpAndSettle();

    // Verify greeting
    expect(find.text('Assalamu Alaikum,'), findsOneWidget);
    expect(find.text('Ali!'), findsOneWidget);

    // Verify main actions
    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('My Bookings'), findsOneWidget);

    // Verify feature labels
    expect(find.text('Healthy'), findsOneWidget);
    expect(find.text('Live Track'), findsOneWidget);
    expect(find.text('Secure'), findsOneWidget);
  });

  // Special Request
  testWidgets('MySpecialRequestsPage shows request list', (
    WidgetTester tester,
  ) async {
    // Mock API response
    RequestService.mockGetUserRequests = () async => [
      {
        'title': 'Extra Meat Packing',
        'description': 'Please pack meat separately',
        'status': 'replied',
        'created_at': DateTime.now().toIso8601String(),
        'reply_message': 'Sure, noted.',
        'replied_at': DateTime.now().toIso8601String(),
      },
    ];

    await tester.pumpWidget(const MaterialApp(home: MySpecialRequestsPage()));

    // Loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let FutureBuilder resolve
    await tester.pumpAndSettle();

    // Page title
    expect(find.text('My Special Requests'), findsOneWidget);

    // Request data
    expect(find.text('Extra Meat Packing'), findsOneWidget);
    expect(find.text('Please pack meat separately'), findsOneWidget);
    expect(find.text('REPLIED'), findsOneWidget);
    expect(find.text('Admin Response:'), findsOneWidget);
    expect(find.text('Sure, noted.'), findsOneWidget);
  });

  // Reset Password
  tearDown(() {
    // Clean mock after each test
    AuthService.mockChangePassword = null;
  });

testWidgets('ResetPasswordPage validates and submits successfully', (WidgetTester tester) async {
  bool called = false;

  AuthService.mockChangePassword = (String current, String next) async {
    called = true;
    expect(current, 'Abc@1234');
    expect(next, 'newpass123');
  };

  await tester.pumpWidget(const MaterialApp(home: ResetPasswordPage()));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField).at(0), 'oldpass123');
  await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
  await tester.enterText(find.byType(TextFormField).at(2), 'newpass123');

  // Scoped finder
  final changePasswordButton = find.widgetWithText(ElevatedButton, 'Change Password');
  await tester.tap(changePasswordButton);
  await tester.pumpAndSettle();

  expect(called, true);
});


  testWidgets('Shows validation error when passwords do not match', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ResetPasswordPage()));

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'oldpass123');

    await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');

    await tester.enterText(find.byType(TextFormField).at(2), 'wrongpass');

    await tester.tap(find.text('Change Password'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  tearDown(() {
    RatingService.mockGetRatings = null;
    RatingService.mockSubmitRatings = null;
  });

  testWidgets('Loads rating data and submits successfully', (
    WidgetTester tester,
  ) async {
    bool submitted = false;

    // 🔹 Mock fetch ratings
    RatingService.mockGetRatings = (String orderId, String userId) async {
      return {
        'submitted': false,
        'order': {
          'admin_id': 'admin-1',
          'admin_name': 'Admin Ali',
          'delivery_person_name': 'Rider Ahmed',
        },
        'ratings': {'adminRating': 0, 'deliveryRating': 0, 'feedback': ''},
      };
    };

    // 🔹 Mock submit ratings
    RatingService.mockSubmitRatings =
        (
          String orderId,
          String userId,
          List<Map<String, dynamic>> ratings,
        ) async {
          submitted = true;

          expect(ratings.first['adminRating'], 5);
          expect(ratings.first['deliveryRating'], 4);
          expect(ratings.first['feedback'], 'Great service');
        };

    await tester.pumpWidget(
      const MaterialApp(
        home: RateOrderPage(orderId: 'order-123', userId: 'user-123'),
      ),
    );

    // Wait for FutureBuilder
    await tester.pumpAndSettle();

    // Verify loaded data
    expect(find.text('Admin: Admin Ali'), findsOneWidget);
    expect(find.text('Delivery: Rider Ahmed'), findsOneWidget);

    // Tap admin stars (5)
    await tester.tap(find.byIcon(Icons.star_border).at(4));
    await tester.pump();

    // Tap delivery stars (4)
    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pump();

    // Enter feedback
    await tester.enterText(find.byType(TextField), 'Great service');

    // Submit
    await tester.tap(find.text('Submit Rating'));
    await tester.pumpAndSettle();

    expect(submitted, true);
    expect(find.text('Thanks for your rating!'), findsOneWidget);
  });

  testWidgets('Shows error when ratings are missing', (
    WidgetTester tester,
  ) async {
    RatingService.mockGetRatings = (String orderId, String userId) async {
      return {
        'submitted': false,
        'order': {
          'admin_id': 'admin-1',
          'admin_name': 'Admin',
          'delivery_person_name': 'Delivery',
        },
        'ratings': {},
      };
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: RateOrderPage(orderId: 'order-123', userId: 'user-123'),
      ),
    );

    await tester.pumpAndSettle();

    // Try submitting without selecting stars
    await tester.tap(find.text('Submit Rating'));
    await tester.pump();

    // Button should still exist (not submitted)
    expect(find.text('Submit Rating'), findsOneWidget);
  });

  tearDown(() {
    AdminDirectoryPage.mockFetchVerifiedAdmins = null;
  });

  testWidgets('Displays verified admins in grid', (WidgetTester tester) async {
    // 🔹 Mock API response
    AdminDirectoryPage.mockFetchVerifiedAdmins = () async {
      return [
        {
          'id': 'admin-1',
          'name': 'Admin Ali',
          'address': 'Karachi',
          'photo_url': '',
        },
        {
          'id': 'admin-2',
          'name': 'Admin Ahmed',
          'address': 'Lahore',
          'photo_url': '',
        },
      ];
    };

    await tester.pumpWidget(const MaterialApp(home: AdminDirectoryPage()));

    // Loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // Admins shown
    expect(find.text('Admin Ali'), findsOneWidget);
    expect(find.text('Admin Ahmed'), findsOneWidget);

    // Buttons
    expect(find.text('View Profile'), findsNWidgets(2));
    expect(find.text('Place Order'), findsNWidgets(2));
  });

  tearDown(() {
    AdminDirectoryPage.mockFetchVerifiedAdmins = null;
  });

  testWidgets('Search filters admins by name', (WidgetTester tester) async {
    AdminDirectoryPage.mockFetchVerifiedAdmins = () async {
      return [
        {'id': '1', 'name': 'Ali', 'address': 'Karachi', 'photo_url': ''},
        {'id': '2', 'name': 'Ahmed', 'address': 'Lahore', 'photo_url': ''},
      ];
    };

    await tester.pumpWidget(const MaterialApp(home: AdminDirectoryPage()));

    await tester.pumpAndSettle();

    // Search
    await tester.enterText(find.byType(TextField), 'Ali');
    await tester.pump();

    // ✅ Scoped finder to only match admin card text
    final aliFinder = find.descendant(
      of: find.byType(GridView),
      matching: find.text('Ali'),
    );

    expect(aliFinder, findsOneWidget); // Only Ali in the admin list
    expect(find.text('Ahmed'), findsNothing); // Ahmed should be filtered out
  });

  testWidgets('Shows empty state when no admins found', (
    WidgetTester tester,
  ) async {
    AdminDirectoryPage.mockFetchVerifiedAdmins = () async => [];

    await tester.pumpWidget(const MaterialApp(home: AdminDirectoryPage()));

    await tester.pumpAndSettle();

    expect(find.text('No verified admins found'), findsOneWidget);
  });

  testWidgets('Shows error message on API failure', (
    WidgetTester tester,
  ) async {
    AdminDirectoryPage.mockFetchVerifiedAdmins = () async {
      throw Exception('API Error');
    };

    await tester.pumpWidget(const MaterialApp(home: AdminDirectoryPage()));

    await tester.pumpAndSettle();

    expect(find.textContaining('Error:'), findsOneWidget);
  });



  // settings
  testWidgets('Settings page loads with currency dropdown', (
    WidgetTester tester,
  ) async {
    SettingsPage.mockCurrencies = () async => ['USD', 'PKR'];
    SettingsPage.mockProfile = () async => {'currency': 'PKR'};
    SettingsPage.mockOpenLink = (_) async {};

  

    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('PKR'), findsOneWidget);
  });

  tearDown(() {
    SettingsPage.mockCurrencies = null;
    SettingsPage.mockProfile = null;
    SettingsPage.mockPaymentSettings = null;
    SettingsPage.mockOpenLink = null;
  });

  tearDown(() {
    SettingsPage.mockCurrencies = null;
    SettingsPage.mockProfile = null;
    SettingsPage.mockPaymentSettings = null;
    SettingsPage.mockOpenLink = null;
  });
}
