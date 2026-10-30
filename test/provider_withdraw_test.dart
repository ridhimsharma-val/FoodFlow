import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_flow/pages/provider/provider_home_tab.dart';
import 'package:food_flow/services/food_rescue_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Provider Withdraw Listing Tests', () {
    testWidgets('Provider can withdraw an available batch directly from card chip', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FoodRescueService.instance.listNewBatch(
        title: 'Withdrawable Biryani Batch',
        category: 'Cooked Meal',
        quantityPortions: 40,
        dietaryType: 'Pure Veg',
        cookedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        safeUntil: DateTime.now().add(const Duration(hours: 3)),
        temperatureCelsius: 65,
        packagingType: 'Foil Trays',
        pickupAddress: 'Indiranagar Central Kitchen',
        providerName: 'Taj Indiranagar',
        providerCategory: 'Hotel',
        location: const LatLng(12.9716, 77.5946),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderHomeTab(
              providerName: 'Taj Indiranagar',
              category: 'Hotel',
              location: 'Indiranagar Central Kitchen',
              latLng: const LatLng(12.9716, 77.5946),
              onOpenPostTab: () {},
              onOpenHistoryTab: () {},
              onOpenNotifications: () {},
              onOpenProfile: () {},
              onDetectLocation: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Withdrawable Biryani Batch'), findsOneWidget);

      final withdrawBtn = find.text('Withdraw');
      expect(withdrawBtn, findsOneWidget);
      await tester.tap(withdrawBtn);
      await tester.pumpAndSettle();

      expect(find.text('Withdraw Listing?'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to withdraw "Withdrawable Biryani Batch"'), findsOneWidget);
      expect(find.text('Keep Listing'), findsOneWidget);
      expect(find.text('Withdraw Food'), findsOneWidget);

      await tester.tap(find.text('Withdraw Food'));
      await tester.pumpAndSettle();

      expect(find.text('Withdrawable Biryani Batch'), findsNothing);
      expect(find.textContaining('withdrawn and delisted successfully'), findsOneWidget);
    });

    testWidgets('Provider can cancel withdrawal and keep listing', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FoodRescueService.instance.listNewBatch(
        title: 'Kept Paneer Curry',
        category: 'Cooked Meal',
        quantityPortions: 25,
        dietaryType: 'Pure Veg',
        cookedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        safeUntil: DateTime.now().add(const Duration(hours: 4)),
        temperatureCelsius: 60,
        packagingType: 'Foil Trays',
        pickupAddress: 'Indiranagar Central Kitchen',
        providerName: 'Taj Indiranagar',
        providerCategory: 'Hotel',
        location: const LatLng(12.9716, 77.5946),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderHomeTab(
              providerName: 'Taj Indiranagar',
              category: 'Hotel',
              location: 'Indiranagar Central Kitchen',
              latLng: const LatLng(12.9716, 77.5946),
              onOpenPostTab: () {},
              onOpenHistoryTab: () {},
              onOpenNotifications: () {},
              onOpenProfile: () {},
              onDetectLocation: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kept Paneer Curry'), findsOneWidget);

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep Listing'));
      await tester.pumpAndSettle();

      expect(find.text('Kept Paneer Curry'), findsOneWidget);
    });
  });
}
