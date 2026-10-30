import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_flow/pages/provider/provider_dashboard.dart';
import 'package:food_flow/pages/receiver/receiver_dashboard.dart';
import 'package:food_flow/services/food_rescue_service.dart';
import 'package:food_flow/widgets/active_rescue_bottom_popup.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Real-Time Three-Role Rescue Communication Tests', () {
    late FoodRescueService service;

    setUp(() {
      service = FoodRescueService.instance;
      service.resetForTesting();
    });

    test('One shared batch update notifies both Provider and Receiver in FoodRescueService', () {
      // 1. Provider lists food
      final batch = service.listNewBatch(
        providerName: 'Grand Hyatt Kitchen',
        providerCategory: 'Hotel & Banquets',
        title: '50 Portions Dal Makhani & Rice',
        category: 'Cooked Meals & Thalis',
        quantityPortions: 50,
        dietaryType: 'Pure Veg',
        temperatureCelsius: 65.0,
        packagingType: 'Thermal Foil Trays',
        pickupAddress: 'Embassy Golf Links, Bengaluru',
        location: const LatLng(12.9500, 77.6400),
      );

      expect(batch.status, equals(BatchStatus.available));
      // Initially no active rescue popup for provider or receiver
      expect(service.getActiveRescueForProvider('Grand Hyatt Kitchen'), isNull);
      expect(service.getActiveRescueForReceiver('Care & Share NGO'), isNull);

      // 2. Receiver claims food
      final claimed = service.claimBatch(
        batchId: batch.id,
        ngoName: 'Care & Share NGO',
      );
      expect(claimed, isTrue);
      expect(batch.status, equals(BatchStatus.claimed));

      // At Step 1 (claimed, waiting for volunteer): tracking popup is NOT visible for either role
      expect(service.getActiveRescueForProvider('Grand Hyatt Kitchen'), isNull);
      expect(service.getActiveRescueForReceiver('Care & Share NGO'), isNull);

      // 3. Volunteer accepts pickup
      final accepted = service.acceptDeliveryTask(
        batchId: batch.id,
        volunteerId: 'VOL-TEST-88',
        volunteerName: 'Deepak Patel',
        volunteerPhone: '+91 91111 22222',
        delayFinalize: false,
      );
      expect(accepted, isTrue);
      expect(batch.assignedCourierName, equals('Deepak Patel'));
      expect(batch.status, equals(BatchStatus.inTransitToPickup));

      // 4. Verification: Both Provider and Receiver find this ONE shared rescue record
      final providerRescue = service.getActiveRescueForProvider('Grand Hyatt Kitchen');
      expect(providerRescue, isNotNull);
      expect(providerRescue!.id, equals(batch.id));
      expect(providerRescue.pickupOtp, equals(batch.pickupOtp));

      final receiverRescue = service.getActiveRescueForReceiver('Care & Share NGO');
      expect(receiverRescue, isNotNull);
      expect(receiverRescue!.id, equals(batch.id));
      expect(receiverRescue.deliveryOtp, equals(batch.deliveryOtp));
    });

    testWidgets('ActiveRescueBottomPopup renders immediately for Provider with PIN and Courier info', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = service.listNewBatch(
        providerName: 'Paradise Biryani Hub',
        providerCategory: 'Restaurant',
        title: '70 Portions Veg Biryani',
        category: 'Cooked Meals & Thalis',
        quantityPortions: 70,
        dietaryType: 'Pure Veg',
        temperatureCelsius: 62.0,
        packagingType: 'Foil Boxes',
        pickupAddress: 'Koramangala 4th Block',
        location: const LatLng(12.9340, 77.6250),
      );

      service.claimBatch(
        batchId: batch.id,
        ngoName: 'Annapurna Trust',
      );

      service.startVolunteerAssignment(
        batchId: batch.id,
        volunteerId: 'VOL-445',
        volunteerName: 'Ravi Teja',
        volunteerPhone: '+91 97777 55555',
        autoFinalize: false,
      );
      service.finalizeVolunteerAssignment(batch.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveRescueBottomPopup(
              role: ActiveRescueRole.provider,
              providerName: 'Paradise Biryani Hub',
            ),
          ),
        ),
      );
      await tester.pump();

      // Check Provider Header & Live Active Status
      expect(find.text('LIVE RESCUE ACTIVE'), findsOneWidget);
      expect(find.text('70 Portions Veg Biryani'), findsOneWidget);
      expect(find.text('Ravi Teja'), findsOneWidget);

      // Check Handover PIN badge
      expect(find.text('PIN: ${batch.pickupOtp}'), findsOneWidget);

      // Check CTA
      expect(find.text('Track Live Delivery / Open Rescue'), findsOneWidget);
    });

    testWidgets('ActiveRescueBottomPopup renders immediately for Receiver with OTP and Delivery info', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = service.listNewBatch(
        providerName: 'Spice Symphony',
        providerCategory: 'Restaurant',
        title: '40 Meals Combo Pack',
        category: 'Cooked Meals & Thalis',
        quantityPortions: 40,
        dietaryType: 'Pure Veg',
        temperatureCelsius: 60.0,
        packagingType: 'Boxes',
        pickupAddress: 'Indiranagar 12th Main',
        location: const LatLng(12.9700, 77.6400),
      );

      service.claimBatch(
        batchId: batch.id,
        ngoName: 'Asha Child Shelter',
      );

      service.startVolunteerAssignment(
        batchId: batch.id,
        volunteerId: 'VOL-446',
        volunteerName: 'Manish Kumar',
        volunteerPhone: '+91 98888 77777',
        autoFinalize: false,
      );
      service.finalizeVolunteerAssignment(batch.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveRescueBottomPopup(
              role: ActiveRescueRole.receiver,
              receiverOrg: 'Asha Child Shelter',
            ),
          ),
        ),
      );
      await tester.pump();

      // Check Receiver Header & Delivery in Progress Status
      expect(find.text('DELIVERY IN PROGRESS'), findsOneWidget);
      expect(find.text('40 Meals Combo Pack'), findsOneWidget);
      expect(find.text('Manish Kumar'), findsOneWidget);

      // Check Delivery OTP badge
      expect(find.text('OTP: ${batch.deliveryOtp}'), findsOneWidget);

      // Check CTA
      expect(find.text('Track Delivery'), findsOneWidget);
    });

    testWidgets('ProviderDashboard renders ActiveRescueBottomPopup when volunteer accepts rescue', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = service.listNewBatch(
        providerName: 'Green Leaf Eatery',
        providerCategory: 'Restaurant',
        title: '30 Portions Fried Rice',
        category: 'Cooked Meals & Thalis',
        quantityPortions: 30,
        dietaryType: 'Pure Veg',
        temperatureCelsius: 60.0,
        packagingType: 'Containers',
        pickupAddress: 'HSR Layout Sector 1',
        location: const LatLng(12.9100, 77.6500),
      );

      service.claimBatch(batchId: batch.id, ngoName: 'Hope Foundation');
      service.startVolunteerAssignment(
        batchId: batch.id,
        volunteerId: 'VOL-777',
        volunteerName: 'Suraj Singh',
        autoFinalize: false,
      );
      service.finalizeVolunteerAssignment(batch.id);

      await tester.pumpWidget(
        const MaterialApp(
          home: ProviderDashboard(),
        ),
      );
      await tester.pump();

      // Bottom popup is present on Provider Dashboard!
      expect(find.text('LIVE RESCUE ACTIVE'), findsOneWidget);
      expect(find.text('PIN: ${batch.pickupOtp}'), findsOneWidget);
    });

    testWidgets('ReceiverDashboard renders ActiveRescueBottomPopup when volunteer accepts rescue', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = service.listNewBatch(
        providerName: 'Bake & Flake',
        providerCategory: 'Bakery',
        title: '50 Fresh Bagels',
        category: 'Bakery & Dry Ration',
        quantityPortions: 50,
        dietaryType: 'Eggless Veg',
        temperatureCelsius: 22.0,
        packagingType: 'Paper Bags',
        pickupAddress: 'Koramangala 1st Block',
        location: const LatLng(12.9250, 77.6300),
      );

      service.claimBatch(batchId: batch.id, ngoName: 'Helping Hands NGO');
      service.startVolunteerAssignment(
        batchId: batch.id,
        volunteerId: 'VOL-888',
        volunteerName: 'Kunal Roy',
        autoFinalize: false,
      );
      service.finalizeVolunteerAssignment(batch.id);

      await tester.pumpWidget(
        const MaterialApp(
          home: ReceiverDashboard(),
        ),
      );
      await tester.pump();

      // Bottom popup is present on Receiver Dashboard!
      expect(find.text('DELIVERY IN PROGRESS'), findsOneWidget);
      expect(find.text('OTP: ${batch.deliveryOtp}'), findsOneWidget);
    });

    testWidgets('ActiveRescueBottomPopup can be dismissed using dismiss icon button', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = service.listNewBatch(
        providerName: 'Taj Gateway Kitchen',
        providerCategory: 'Hotel',
        title: '60 Portions Pulav',
        category: 'Cooked Meals & Thalis',
        quantityPortions: 60,
        dietaryType: 'Pure Veg',
        temperatureCelsius: 65.0,
        packagingType: 'Boxes',
        pickupAddress: 'Residency Road',
        location: const LatLng(12.9700, 77.6000),
      );

      service.claimBatch(batchId: batch.id, ngoName: 'Seva Trust');
      service.startVolunteerAssignment(
        batchId: batch.id,
        volunteerId: 'VOL-999',
        volunteerName: 'Aakash Verma',
        autoFinalize: false,
      );
      service.finalizeVolunteerAssignment(batch.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveRescueBottomPopup(
              role: ActiveRescueRole.provider,
              providerName: 'Taj Gateway Kitchen',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('LIVE RESCUE ACTIVE'), findsOneWidget);

      // Tap the dismiss icon button
      final dismissBtn = find.byIcon(Icons.close_rounded);
      expect(dismissBtn, findsWidgets);
      await tester.tap(dismissBtn.first);
      await tester.pump();

      // Popup is cleanly dismissed
      expect(find.text('LIVE RESCUE ACTIVE'), findsNothing);
    });

    testWidgets('Complete lifecycle test: Popup hidden on claim and assigning, visible only after volunteer acceptance', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // STEP 1 — PROVIDER LISTS FOOD
      final batch = service.listNewBatch(
        providerName: 'Royal Spice Kitchen',
        providerCategory: 'Restaurant',
        title: '45 Portions Paneer Butter Masala',
        category: 'Cooked Meals & Thalis',
        quantityPortions: 45,
        dietaryType: 'Pure Veg',
        temperatureCelsius: 64.0,
        packagingType: 'Foil Boxes',
        pickupAddress: 'Indiranagar 100ft Road',
        location: const LatLng(12.9716, 77.6412),
      );
      expect(batch.status, equals(BatchStatus.available));
      expect(batch.isVolunteerAcceptedAndActive, isFalse);

      // STEP 2 — RECEIVER CLAIMS FOOD
      final claimed = service.claimBatch(
        batchId: batch.id,
        ngoName: 'Compassion Shelter NGO',
      );
      expect(claimed, isTrue);
      expect(batch.status, equals(BatchStatus.claimed));
      expect(batch.assignedCourierId, isNull);
      expect(batch.isVolunteerAcceptedAndActive, isFalse);

      // Verify Provider & Receiver active rescue lookup returns null
      expect(service.getActiveRescueForProvider('Royal Spice Kitchen'), isNull);
      expect(service.getActiveRescueForReceiver('Compassion Shelter NGO'), isNull);

      // Verify Provider Dashboard does NOT render tracking popup
      await tester.pumpWidget(
        const MaterialApp(
          home: ProviderDashboard(),
        ),
      );
      await tester.pump();
      expect(find.text('LIVE RESCUE ACTIVE'), findsNothing);
      expect(find.text('Track Live Delivery / Open Rescue'), findsNothing);

      // Verify Receiver Dashboard does NOT render tracking popup
      await tester.pumpWidget(
        const MaterialApp(
          home: ReceiverDashboard(),
        ),
      );
      await tester.pump();
      expect(find.text('DELIVERY IN PROGRESS'), findsNothing);
      expect(find.text('Track Delivery'), findsNothing);

      // STEP 3 — WAITING FOR VOLUNTEER (volunteerAssigning stage)
      service.startVolunteerAssignment(
        batchId: batch.id,
        volunteerId: 'VOL-PENDING-1',
        volunteerName: 'Ajay Verma',
        autoFinalize: false,
      );
      expect(batch.status, equals(BatchStatus.volunteerAssigning));
      expect(batch.isVolunteerAcceptedAndActive, isFalse);

      // Neither Provider nor Receiver sees tracking popup during volunteerAssigning stage
      expect(service.getActiveRescueForProvider('Royal Spice Kitchen'), isNull);
      expect(service.getActiveRescueForReceiver('Compassion Shelter NGO'), isNull);

      await tester.pumpWidget(
        const MaterialApp(
          home: ProviderDashboard(),
        ),
      );
      await tester.pump();
      expect(find.text('LIVE RESCUE ACTIVE'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: ReceiverDashboard(),
        ),
      );
      await tester.pump();
      expect(find.text('DELIVERY IN PROGRESS'), findsNothing);

      // STEP 4 — VOLUNTEER EXPLICITLY ACCEPTS PICKUP
      service.finalizeVolunteerAssignment(batch.id);
      expect(batch.status, equals(BatchStatus.inTransitToPickup));
      expect(batch.assignedCourierId, isNotNull);
      expect(batch.isVolunteerAcceptedAndActive, isTrue);

      // Now Provider Dashboard renders the active tracking popup!
      await tester.pumpWidget(
        const MaterialApp(
          home: ProviderDashboard(),
        ),
      );
      await tester.pump();
      expect(find.text('LIVE RESCUE ACTIVE'), findsOneWidget);
      expect(find.text('PIN: ${batch.pickupOtp}'), findsOneWidget);
      expect(find.text('Track Live Delivery / Open Rescue'), findsOneWidget);

      // Receiver Dashboard also renders the active tracking popup!
      await tester.pumpWidget(
        const MaterialApp(
          home: ReceiverDashboard(),
        ),
      );
      await tester.pump();
      expect(find.text('DELIVERY IN PROGRESS'), findsOneWidget);
      expect(find.text('OTP: ${batch.deliveryOtp}'), findsOneWidget);
      expect(find.text('Track Delivery'), findsOneWidget);
    });

    test('Refresh / Reconnection simulation restores popup eligibility only when volunteer is assigned', () {
      // 1. Claimed batch without volunteer: not eligible
      final unassignedJson = {
        'id': 'BATCH-REFRESH-1',
        'provider_name': 'Green Curry',
        'provider_category': 'Kitchen',
        'pickup_latitude': 12.97,
        'pickup_longitude': 77.64,
        'title': '30 Meals',
        'category': 'Meals',
        'quantity_portions': 30,
        'dietary_type': 'Veg',
        'status': 'claimed',
        'claimed_by_ngo_name': 'Hope NGO',
        'assigned_courier_id': null,
      };
      final unassignedBatch = SurplusBatch.fromJson(unassignedJson);
      expect(unassignedBatch.isVolunteerAcceptedAndActive, isFalse);

      // 2. Assigning stage: not eligible
      final assigningJson = {
        'id': 'BATCH-REFRESH-2',
        'provider_name': 'Green Curry',
        'provider_category': 'Kitchen',
        'pickup_latitude': 12.97,
        'pickup_longitude': 77.64,
        'title': '30 Meals',
        'category': 'Meals',
        'quantity_portions': 30,
        'dietary_type': 'Veg',
        'status': 'volunteerAssigning',
        'claimed_by_ngo_name': 'Hope NGO',
        'assigned_courier_id': 'VOL-99',
      };
      final assigningBatch = SurplusBatch.fromJson(assigningJson);
      expect(assigningBatch.isVolunteerAcceptedAndActive, isFalse);

      // 3. Post-acceptance stage with valid volunteer ID: eligible!
      final acceptedJson = {
        'id': 'BATCH-REFRESH-3',
        'provider_name': 'Green Curry',
        'provider_category': 'Kitchen',
        'pickup_latitude': 12.97,
        'pickup_longitude': 77.64,
        'title': '30 Meals',
        'category': 'Meals',
        'quantity_portions': 30,
        'dietary_type': 'Veg',
        'status': 'inTransitToPickup',
        'claimed_by_ngo_name': 'Hope NGO',
        'assigned_courier_id': 'VOL-99',
      };
      final acceptedBatch = SurplusBatch.fromJson(acceptedJson);
      expect(acceptedBatch.isVolunteerAcceptedAndActive, isTrue);
    });
  });
}
