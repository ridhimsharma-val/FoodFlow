import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:food_flow/pages/dashboard.dart';
import 'package:food_flow/pages/provider/provider_dashboard.dart';
import 'package:food_flow/services/ai_food_assistant_service.dart';
import 'package:food_flow/services/impact_calculation_service.dart';
import 'package:food_flow/services/matching_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Provider Redesign Unit Tests', () {
    test('AiFoodAssistantService extracts structured details from natural language', () async {
      final input = 'I have 40 packets of rice and dal prepared at 6 pm. Pickup before 9.';
      final result = await AiFoodAssistantService.extractFromText(input);

      expect(result, isNotNull);
      expect(result!.foodName, contains('Rice & Dal'));
      expect(result.quantityServings, equals(40));
      expect(result.dietaryType, equals('Pure Veg'));
      expect(result.preparedAt!.hour, equals(18));
      expect(result.bestBefore!.hour, equals(21));
    });

    test('ImpactCalculationService calculates correct environmental and social metrics', () {
      final metrics = ImpactCalculationService.calculate([]);
      expect(metrics.mealsRedistributed, greaterThanOrEqualTo(0));
      expect(metrics.foodSavedKg, equals(metrics.mealsRedistributed * 0.5));
      expect(metrics.peopleServed, equals((metrics.mealsRedistributed * 0.75).round()));
      expect(metrics.co2AvoidedKg, equals(double.parse((metrics.mealsRedistributed * 0.67).toStringAsFixed(1))));
    });

    test('MatchingService returns ranked receiver matches with criteria', () async {
      final matches = await MatchingService.findMatches(
        providerLocation: const LatLng(12.9784, 77.6408),
        servings: 50,
        category: 'Cooked Meal',
        dietaryType: 'Pure Veg',
      );

      expect(matches.isNotEmpty, isTrue);
      final top = matches.first;
      expect(top.organizationName, isNotEmpty);
      expect(top.matchScorePercentage, greaterThanOrEqualTo(80));
      expect(top.matchReasons.isNotEmpty, isTrue);
    });
  });

  group('ProviderDashboard Widget Tests', () {
    testWidgets('ProviderDashboard renders clean white+yellow layout and bottom navigation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ProviderDashboard(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Top greeting
      expect(find.textContaining('Good morning'), findsOneWidget);

      // Verify Prominent Main CTA
      expect(find.widgetWithText(ElevatedButton, 'Post Surplus Food'), findsOneWidget);

      // Verify 4 compact statistics
      expect(find.text('Meals Posted'), findsOneWidget);
      expect(find.text('Claimed'), findsWidgets);
      expect(find.text('Distributed'), findsOneWidget);
      expect(find.text('Food Saved'), findsOneWidget);

      // Verify Today's Surplus Meals section
      expect(find.text("Today's Surplus Meals"), findsOneWidget);
      expect(find.text('View All →'), findsOneWidget);

      // Verify Bottom Navigation tabs
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Post'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Impact'), findsOneWidget);
    });

    testWidgets('ProviderDashboard bottom nav navigates to Post, History, and Impact',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ProviderDashboard(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Post' tab
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      expect(find.text('Post Surplus Food'), findsOneWidget);
      expect(find.text('AI Food Post Assistant'), findsNothing);
      expect(find.text('Food Name'), findsOneWidget);
      expect(find.text('Smart Dynamic Markdown Pricing'), findsOneWidget);
      expect(find.text('Base Price / Portion (₹)'), findsOneWidget);
      expect(find.text('Minimum Price (₹)'), findsOneWidget);
      expect(find.text('Food Type Decay Velocity (γ)'), findsNothing);
      expect(find.text('Initial Quality Tier'), findsNothing);
      expect(find.text('Clear the Kitchen (50% Flash Markdown)'), findsNothing);
      expect(find.text('Live Markdown Preview'), findsOneWidget);
      expect(find.text('Review & Confirm →'), findsOneWidget);

      // Tap 'History' tab
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('Food History'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Total Meals Donated'), findsOneWidget);

      // Tap 'Impact' tab
      await tester.tap(find.text('Impact'));
      await tester.pumpAndSettle();

      expect(find.text('Your Impact'), findsOneWidget);
      expect(find.text('Meals Redistributed'), findsOneWidget);
      expect(find.text('A Greener Tomorrow'), findsOneWidget);
    });

    testWidgets('ProviderDashboard renders Log Out button which opens confirmation dialog',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ProviderDashboard(),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap 'Log Out' button in top bar
      final logoutBtn = find.text('Log Out');
      expect(logoutBtn, findsOneWidget);

      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Confirms sign out dialog is displayed
      expect(find.text('Confirm Sign Out'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('DashboardPage allows switching role between provider, receiver, and volunteer',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardPage(initialRole: 'provider'),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer using menu icon
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Tap 'Switch Role' tile in AppDrawer
      await tester.tap(find.text('Switch Role'));
      await tester.pumpAndSettle();

      expect(find.text('Switch Portal / Role'), findsOneWidget);
      expect(find.text('Receiver (NGO & Shelters)'), findsOneWidget);
      expect(find.text('Volunteer Rescue Squad'), findsOneWidget);
      expect(find.text('Log Out to Switch Account'), findsOneWidget);

      // Select Receiver role: must prompt to log out first
      await tester.tap(find.text('Receiver (NGO & Shelters)'));
      await tester.pumpAndSettle();

      expect(find.text('Log Out to Switch Role?'), findsOneWidget);
      expect(find.textContaining('Each Food Flow account is bound to a single verified role'), findsOneWidget);
      expect(find.text('Log Out & Switch'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Cancel keeps user on provider portal
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Log Out to Switch Role?'), findsNothing);
    });

    testWidgets('DashboardPage renders cleanly and responsively without artificial simulator controls',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardPage(initialRole: 'provider'),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no simulator UI or view toggles exist
      expect(find.textContaining('Phone Simulation'), findsNothing);
      expect(find.text('Interface Mode:'), findsNothing);
      expect(find.text('App View'), findsNothing);
      expect(find.text('Web View'), findsNothing);

      // Verify mobile viewport also renders without simulator artifacts
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();

      expect(find.textContaining('Phone Simulation'), findsNothing);
      expect(find.text('Interface Mode:'), findsNothing);
      expect(find.text('App View'), findsNothing);
      expect(find.text('Web View'), findsNothing);
    });

    testWidgets('Provider Post Food includes interactive map in both form and review steps',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ProviderDashboard(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Dispatch Hub & Relief Network map on Home Tab
      expect(find.text('Dispatch Hub & Relief Network'), findsOneWidget);
      expect(find.text('Recenter GPS'), findsOneWidget);

      // Navigate to Post Food tab
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      // Verify Step 0 Form contains Pickup Pin map & instructions
      expect(find.text('Pickup Location & Kitchen Pin'), findsOneWidget);
      expect(find.text('Detect GPS'), findsOneWidget);
      expect(find.text('Tap anywhere on map to reposition pickup pin / dock'), findsOneWidget);

      // Proceed to Step 1: Review & Confirm
      final reviewBtn = find.text('Review & Confirm →');
      await tester.ensureVisible(reviewBtn);
      await tester.tap(reviewBtn);
      await tester.pumpAndSettle();

      // Verify Step 1 Review contains Pickup Location Pin Confirmation map preview
      expect(find.text('Pickup Location Pin Confirmation'), findsOneWidget);
      expect(find.text('Dispatch dock verified for volunteers & relief receivers'), findsOneWidget);
      expect(find.text('Post Food'), findsOneWidget);
    });
  });
}
