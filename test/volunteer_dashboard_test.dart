import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:food_flow/pages/dashboard.dart';
import 'package:food_flow/pages/volunteer/volunteer_dashboard.dart';
import 'package:food_flow/pages/volunteer/volunteer_accept_task_dialog.dart';
import 'package:food_flow/pages/volunteer/volunteer_active_task_page.dart';
import 'package:food_flow/pages/volunteer/volunteer_task_details_dialog.dart';
import 'package:food_flow/services/food_rescue_service.dart';
import 'package:food_flow/services/matching_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Seed a standard delivery batch into FoodRescueService and claim it for an NGO
    final batch = FoodRescueService.instance.listNewBatch(
      providerName: 'ABC Restaurant',
      providerCategory: 'Commercial Kitchen',
      title: 'Rice & Dal',
      category: 'Cooked Meals',
      quantityPortions: 50,
      dietaryType: 'Pure Veg',
      temperatureCelsius: 65.0,
      packagingType: 'Thermal Cambros',
      pickupAddress: 'Greater Noida Hub Dock 2',
      location: const LatLng(12.9750, 77.6100),
      safeHours: 4,
    );
    FoodRescueService.instance.claimBatch(
      batchId: batch.id,
      ngoName: 'Helping Hands NGO',
    );
  });

  group('Volunteer Recommendation Unit Tests', () {
    test('VolunteerRecommendationService calculates match scores and sorts recommendations', () {
      final available = FoodRescueService.instance.batches;
      final recommendations = VolunteerRecommendationService.getRecommendations(
        availableTasks: available,
        volunteerLocation: const LatLng(12.9750, 77.6100),
      );

      expect(recommendations, isNotEmpty);
      expect(recommendations.first.matchScore, greaterThanOrEqualTo(60));
      expect(recommendations.first.recommendationReason, isNotEmpty);
    });
  });

  group('Volunteer Dashboard Widget Tests', () {
    testWidgets('VolunteerDashboard renders Home tab with greeting, availability toggle, stats, and CTA', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: VolunteerDashboard(),
        ),
      );
      await tester.pump();

      // Greeting & Location
      expect(find.textContaining('Yash'), findsOneWidget);
      expect(find.textContaining('Hub'), findsWidgets);

      // Availability toggle
      expect(find.text('🟢 Available for Tasks'), findsOneWidget);

      // 4 Core Statistics
      expect(find.text('Tasks Completed'), findsOneWidget);
      expect(find.text('Meals Delivered'), findsOneWidget);
      expect(find.text('Food Rescued'), findsOneWidget);
      expect(find.text('CO₂ Avoided'), findsOneWidget);

      // Main CTA and Sections
      expect(find.text('Find Nearby Tasks'), findsOneWidget);
      expect(find.text('Nearby Delivery Tasks'), findsOneWidget);
      expect(find.text('Recommended For You'), findsOneWidget);
      expect(find.text('Nearby Delivery Map'), findsOneWidget);
    });

    testWidgets('VolunteerDashboard bottom navigation switches between all 4 tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: VolunteerDashboard(),
        ),
      );
      await tester.pump();

      // 1. Tap Tasks tab in bottom navigation bar
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      expect(find.text('Available Tasks'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // Search bar
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Nearby'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      // 2. Tap History tab
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('Task History'), findsOneWidget);
      expect(find.text('Distance Covered'), findsOneWidget);
      expect(find.text('Successful Deliveries'), findsOneWidget);
      expect(find.textContaining('Active ('), findsOneWidget);
      expect(find.textContaining('Completed ('), findsOneWidget);
      expect(find.textContaining('Cancelled ('), findsOneWidget);

      // 3. Tap Impact tab
      await tester.tap(find.text('Impact'));
      await tester.pumpAndSettle();

      expect(find.text('Your Impact'), findsOneWidget);
      expect(find.text('A Greener Tomorrow'), findsOneWidget);
      expect(find.text('Meals Delivered'), findsOneWidget);
      expect(find.text('Food Rescued'), findsOneWidget);
      expect(find.text('People Served'), findsOneWidget);
      expect(find.text('Delivery Distance'), findsOneWidget);

      // 4. Tap Home tab to navigate back
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('Nearby Delivery Tasks'), findsOneWidget);
    });

    testWidgets('VolunteerTaskDetailsDialog displays food and route breakdown', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = FoodRescueService.instance.batches.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VolunteerTaskDetailsDialog.show(
                  context,
                  batch: batch,
                  pickupDistanceKm: 1.2,
                  deliveryDistanceKm: 2.8,
                  totalRouteKm: 4.0,
                  pickupWindow: '7:00 PM – 8:00 PM',
                ),
                child: const Text('Open Details'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      expect(find.text(batch.title), findsWidgets);
      expect(find.text('${batch.quantityPortions} meals'), findsWidgets);
      expect(find.text('Total route:'), findsOneWidget);
      expect(find.text('4.0 km'), findsOneWidget);
      expect(find.text('Accept Task'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('VolunteerAcceptTaskDialog displays confirmation and action buttons', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = FoodRescueService.instance.batches.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VolunteerAcceptTaskDialog.show(
                  context,
                  batch: batch,
                  pickupDistanceKm: 1.2,
                  deliveryDistanceKm: 2.8,
                  totalRouteKm: 4.0,
                ),
                child: const Text('Open Accept'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Accept'));
      await tester.pumpAndSettle();

      expect(find.text('Accept this delivery?'), findsOneWidget);
      expect(find.text(batch.providerName), findsOneWidget);
      expect(find.text('${batch.quantityPortions} meals'), findsOneWidget);
      expect(find.text('Accept Task'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('VolunteerActiveTaskPage renders 8-step progress timeline and pickup step', (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = FoodRescueService.instance.batches.first;

      await tester.pumpWidget(
        MaterialApp(
          home: VolunteerActiveTaskPage(batch: batch),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Delivery Tracking'), findsOneWidget);
      expect(find.text('Delivery Progress Timeline'), findsOneWidget);
      expect(find.text('Task Accepted'), findsOneWidget);
      expect(find.text('Going to Pickup'), findsOneWidget);
      expect(find.text('Arrived at Provider'), findsOneWidget);
      expect(find.text('Food Collected'), findsOneWidget);
      expect(find.text('Going to Receiver'), findsOneWidget);
      expect(find.text('Arrived at Receiver'), findsOneWidget);
      expect(find.text('Food Delivered'), findsOneWidget);
      expect(find.text('Task Completed'), findsOneWidget);

      expect(find.text('Pickup Food'), findsOneWidget);
      expect(find.text("I've Arrived"), findsOneWidget);
    });

    testWidgets('VolunteerAcceptTaskDialog transitions to Task Accepted and Start Pickup moves to live tracking', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = FoodRescueService.instance.batches.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VolunteerAcceptTaskDialog.show(
                  context,
                  batch: batch,
                  pickupDistanceKm: 1.2,
                  deliveryDistanceKm: 2.8,
                  totalRouteKm: 4.0,
                ),
                child: const Text('Open Accept'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Accept'));
      await tester.pumpAndSettle();

      // Tap Accept Task button in confirmation dialog
      await tester.tap(find.text('Accept Task'));
      await tester.pumpAndSettle();

      // Verify celebratory Task Accepted screen appears with Start Pickup CTA
      expect(find.text('Task Accepted 🎉'), findsOneWidget);
      expect(find.text('Start Pickup'), findsOneWidget);

      // Tap Start Pickup
      await tester.tap(find.text('Start Pickup'));
      await tester.pumpAndSettle();

      // Verify moved to Live Delivery Tracking
      expect(find.text('Live Delivery Tracking'), findsOneWidget);
    });

    testWidgets('VolunteerActiveTaskPage attaches OsmMapWidget when Start Navigation is demanded', (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = FoodRescueService.instance.batches.first;

      await tester.pumpWidget(
        MaterialApp(
          home: VolunteerActiveTaskPage(batch: batch),
        ),
      );
      await tester.pumpAndSettle();

      // Initially map prompt is shown
      expect(find.text('GPS Route Map Available'), findsOneWidget);

      // Tap Start Navigation
      await tester.tap(find.text('Start Navigation').first);
      await tester.pumpAndSettle();

      // Verify interactive navigation map header & controls attached
      expect(find.textContaining('GPS NAVIGATION: TO PICKUP'), findsOneWidget);
      expect(find.textContaining('Turn-by-turn:'), findsOneWidget);
      expect(find.text('Hide Map'), findsOneWidget);
    });

    testWidgets('VolunteerActiveTaskPage performs two-sided OTP verification at provider and receiver steps', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = FoodRescueService.instance.batches.first;

      await tester.pumpWidget(
        MaterialApp(
          home: VolunteerActiveTaskPage(batch: batch),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Arrive at Provider
      await tester.ensureVisible(find.text("I've Arrived"));
      await tester.tap(find.text("I've Arrived"));
      await tester.pumpAndSettle();

      expect(find.text('Provider Handover Verification OTP'), findsOneWidget);

      // Verify empty OTP validation
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Confirm Pickup'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Pickup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Please enter the 4-digit Pickup OTP'), findsOneWidget);

      // Auto-fill valid pickup OTP and confirm
      await tester.ensureVisible(find.text('Auto-fill'));
      await tester.tap(find.text('Auto-fill'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Confirm Pickup'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Pickup'));
      await tester.pumpAndSettle();

      // Successfully collected food -> Delivery phase
      expect(find.text('Deliver Food'), findsOneWidget);
      expect(find.text('Food Collected'), findsWidgets);

      // 2. Arrive at Receiver
      await tester.ensureVisible(find.text("I've Arrived"));
      await tester.tap(find.text("I've Arrived"));
      await tester.pumpAndSettle();

      expect(find.text('Receiver Delivery Verification OTP'), findsOneWidget);

      // Auto-fill valid delivery OTP and confirm
      await tester.ensureVisible(find.text('Auto-fill'));
      await tester.tap(find.text('Auto-fill'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Confirm Delivery'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Delivery'));
      await tester.pumpAndSettle();

      // Verify Task Completed celebration appears
      expect(find.text('Task Completed 🎉'), findsWidgets);
      expect(find.textContaining('Food Rescued'), findsWidgets);
    });

    testWidgets('DashboardPage correctly routes to VolunteerDashboard when initialRole is volunteer', (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardPage(initialRole: 'volunteer'),
        ),
      );
      await tester.pump();

      expect(find.byType(VolunteerDashboard), findsOneWidget);
      expect(find.textContaining('Yash'), findsOneWidget);
    });
  });
}
