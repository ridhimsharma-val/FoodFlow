import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:food_flow/pages/receiver/food_details_dialog.dart';
import 'package:food_flow/pages/receiver/claim_confirmation_dialog.dart';
import 'package:food_flow/pages/receiver/my_claim_details_page.dart';
import 'package:food_flow/pages/receiver/receiver_dashboard.dart';
import 'package:food_flow/services/food_rescue_service.dart';
import 'package:food_flow/services/matching_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Ensure test seed data is available in FoodRescueService
    FoodRescueService.instance.listNewBatch(
      providerName: 'Taj Culinary Kitchen',
      providerCategory: 'Luxury Hotel',
      title: 'Biryani Special Portions',
      category: 'Cooked Meals & Thalis',
      quantityPortions: 60,
      dietaryType: 'Pure Veg',
      temperatureCelsius: 65.0,
      packagingType: 'Thermal Cambros',
      pickupAddress: 'MG Road, Bengaluru',
      location: const LatLng(12.9750, 77.6100),
      safeHours: 4,
    );
  });

  group('Receiver Recommendation Unit Tests', () {
    test('ReceiverRecommendationService calculates match scores and sorts recommendations', () {
      final available = FoodRescueService.instance.batches;
      final recommendations = ReceiverRecommendationService.getRecommendations(
        availableBatches: available,
        receiverLocation: const LatLng(12.9750, 77.6100),
      );

      expect(recommendations, isNotEmpty);
      expect(recommendations.first.matchScore, greaterThanOrEqualTo(60));
      expect(recommendations.first.recommendationReason, isNotEmpty);
    });
  });

  group('Receiver Dashboard Widget Tests', () {
    testWidgets('ReceiverDashboard renders Home tab with stats, CTA, and recommendations', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ReceiverDashboard(),
        ),
      );
      await tester.pump();

      // Greetings & Org info
      expect(find.textContaining('Asha Verma'), findsOneWidget);
      expect(find.text('Helping Hands NGO'), findsOneWidget);

      // 4 key statistics
      expect(find.text('Meals Claimed'), findsOneWidget);
      expect(find.text('Pickup Confirmed'), findsOneWidget);
      expect(find.text('Distributed'), findsOneWidget);
      expect(find.text('Food Saved'), findsOneWidget);

      // CTA and Sections
      expect(find.text('Find Available Food'), findsOneWidget);
      expect(find.text('Available Near You'), findsOneWidget);
      expect(find.text('Recommended For You'), findsOneWidget);
      expect(find.text('Nearby Food Map'), findsOneWidget);
    });

    testWidgets('ReceiverDashboard bottom navigation switches tabs correctly', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ReceiverDashboard(),
        ),
      );
      await tester.pump();

      // Tap 'Browse' tab in navigation bar
      await tester.tap(find.text('Browse'));
      await tester.pumpAndSettle();

      // Verify Browse page is displayed
      expect(find.byType(TextField), findsOneWidget); // Search bar
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Veg'), findsOneWidget);
      expect(find.text('Non-Veg'), findsOneWidget);
      expect(find.text('Near Me'), findsOneWidget);

      // Tap 'My Claims' tab in navigation bar
      await tester.tap(find.text('My Claims'));
      await tester.pumpAndSettle();

      // Verify My Claims page is displayed
      expect(find.textContaining('Claimed ('), findsOneWidget);
      expect(find.textContaining('Completed ('), findsOneWidget);
      expect(find.text('Total Meals Claimed'), findsOneWidget);

      // Tap 'Impact' tab in navigation bar
      await tester.tap(find.text('Impact'));
      await tester.pumpAndSettle();

      // Verify Impact page is displayed
      expect(find.text('Your Impact'), findsOneWidget);
      expect(find.text('Meals Redistributed'), findsOneWidget);
      expect(find.text('Food Saved'), findsOneWidget);
      expect(find.text('People Served'), findsOneWidget);
      expect(find.text('Estimated CO₂ Avoided'), findsOneWidget);

      // Tap 'Home' tab to navigate back
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('Available Near You'), findsOneWidget);
    });

    testWidgets('FoodDetailsDialog displays food specifications and triggers claim modal', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = FoodRescueService.instance.batches.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FoodDetailsDialog.show(
                  context,
                  batch: batch,
                  distanceKm: 1.2,
                ),
                child: const Text('Open Details'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      // Verify food details modal
      expect(find.text(batch.title), findsOneWidget);
      expect(find.text('${batch.quantityPortions} servings'), findsOneWidget);
      expect(find.text('Claim Food'), findsOneWidget);
    });

    testWidgets('ClaimConfirmationDialog displays confirmation summary and claim button', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = FoodRescueService.instance.batches.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ClaimConfirmationDialog.show(
                  context,
                  batch: batch,
                  distanceKm: 1.2,
                ),
                child: const Text('Open Confirm'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Confirm'));
      await tester.pumpAndSettle();
      // Verify confirmation dialog
      expect(find.text('Confirm Claim'), findsWidgets);
      expect(find.text(batch.title), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('MyClaimDetailsPage renders Delivery Verification OTP card and distribution timeline', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = FoodRescueService.instance.batches.first;

      await tester.pumpWidget(
        MaterialApp(
          home: MyClaimDetailsPage(batch: batch),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Claim'), findsOneWidget);
      expect(find.text('Delivery Verification OTP'), findsOneWidget);
      expect(find.text(batch.deliveryOtp), findsOneWidget);
      expect(find.textContaining('Share with volunteer courier at drop-off'), findsOneWidget);
      expect(find.text('Claim & Distribution Timeline'), findsOneWidget);
    });
  });
}
