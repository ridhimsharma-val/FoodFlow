import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_flow/services/food_rescue_service.dart';
import 'package:food_flow/widgets/rescue_assignment_loading_screen.dart';
import 'package:food_flow/widgets/shared_rescue_tracking_page.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Real-Time Rescue Lifecycle & Simulation Tests', () {
    late FoodRescueService service;

    setUp(() {
      service = FoodRescueService.instance;
    });

    test('Full lifecycle from available -> claimed -> volunteerAssigning -> inTransitToPickup -> delivered', () {
      final batch = service.listNewBatch(
        providerName: 'Taj Conclave Banquet',
        providerCategory: 'Banquet Hall',
        title: '80 Portions Biryani & Salan',
        category: 'Cooked Meals & Thalis',
        quantityPortions: 80,
        dietaryType: 'Non-Veg (Halal)',
        temperatureCelsius: 65.0,
        packagingType: 'Thermal Foil Containers',
        pickupAddress: 'MG Road, Bengaluru',
        location: const LatLng(12.9750, 77.6100),
        safeHours: 4,
      );

      expect(batch.status, equals(BatchStatus.available));

      // 1. Receiver claims the food
      final claimed = service.claimBatch(
        batchId: batch.id,
        ngoName: 'Sneha Care Shelter',
        requestVolunteerCourier: false,
      );
      expect(claimed, isTrue);
      expect(batch.status, equals(BatchStatus.claimed));

      // 2. Start volunteer assignment (connecting state)
      final assigningStarted = service.startVolunteerAssignment(
        batchId: batch.id,
        volunteerId: 'VOL-4451',
        volunteerName: 'Rohan Sharma',
        volunteerPhone: '+91 98888 12345',
        autoFinalize: false,
      );
      expect(assigningStarted, isTrue);
      expect(batch.status, equals(BatchStatus.volunteerAssigning));
      expect(batch.assignedCourierName, equals('Rohan Sharma'));
      expect(batch.courierCurrentLat, isNotNull);

      // 3. Finalize volunteer assignment (live tracking begins)
      service.finalizeVolunteerAssignment(batch.id);
      expect(batch.status, equals(BatchStatus.inTransitToPickup));
      expect(batch.assignedCourierName, equals('Rohan Sharma'));

      // 4. Update status to arrivedAtPickup
      service.updateTaskDeliveryStatus(batch.id, BatchStatus.arrivedAtPickup);
      expect(batch.status, equals(BatchStatus.arrivedAtPickup));

      // 5. Verify pickup OTP (dual-OTP stage 1)
      final otpValid = service.verifyPickupOtp(batch.id, batch.pickupOtp);
      expect(otpValid, isTrue);
      expect(batch.status, equals(BatchStatus.pickedUp));

      // 6. Transition to inTransit
      service.updateTaskDeliveryStatus(batch.id, BatchStatus.inTransit);
      expect(batch.status, equals(BatchStatus.inTransit));

      // 7. Transition to arrivedAtReceiver
      service.updateTaskDeliveryStatus(batch.id, BatchStatus.arrivedAtReceiver);
      expect(batch.status, equals(BatchStatus.arrivedAtReceiver));

      // 8. Verify delivery OTP (dual-OTP stage 2)
      final deliveryValid = service.verifyDeliveryOtp(batch.id, batch.deliveryOtp);
      expect(deliveryValid, isTrue);
      expect(batch.status, equals(BatchStatus.delivered));
    });

    test('Simulation methods start, pause, resume, and speed toggle', () {
      final batch = service.listNewBatch(
        providerName: 'Apex Kitchen',
        providerCategory: 'Restaurant',
        title: '25 Veg Meals',
        category: 'Cooked Meals & Thalis',
        quantityPortions: 25,
        dietaryType: 'Pure Veg',
        temperatureCelsius: 60.0,
        packagingType: 'Sealed Bowls',
        pickupAddress: 'Indiranagar 100ft Rd',
        location: const LatLng(12.9716, 77.6412),
      );

      service.claimBatch(batchId: batch.id, ngoName: 'Hope Trust');
      service.acceptDeliveryTask(
        batchId: batch.id,
        volunteerId: 'VOL-99',
        volunteerName: 'Priya K',
        volunteerPhone: '+91 91234 56789',
        delayFinalize: false,
      );

      expect(service.getSimulationSpeed(batch.id), equals(1.0));

      service.setSimulationSpeed(batch.id, 2.0);
      expect(service.getSimulationSpeed(batch.id), equals(2.0));

      service.startSimulatedMovement(batch.id, speedMultiplier: 2.0);
      expect(service.isSimulationRunning(batch.id), isTrue);

      service.pauseSimulatedMovement(batch.id);
      expect(service.isSimulationPaused(batch.id), isTrue);

      service.resumeSimulatedMovement(batch.id);
      expect(service.isSimulationPaused(batch.id), isFalse);

      service.stopSimulatedMovement(batch.id);
      expect(service.isSimulationRunning(batch.id), isFalse);
    });

    test('Volunteer cancellation rolls back task to claimed for re-assignment', () {
      final batch = service.listNewBatch(
        providerName: 'Central Bakery',
        providerCategory: 'Bakery',
        title: '40 Croissants',
        category: 'Bakery & Dry Ration',
        quantityPortions: 40,
        dietaryType: 'Eggless Veg',
        temperatureCelsius: 22.0,
        packagingType: 'Boxes',
        pickupAddress: 'Koramangala 5th Block',
        location: const LatLng(12.9352, 77.6245),
      );

      service.claimBatch(batchId: batch.id, ngoName: 'Child Life Foundation');
      service.acceptDeliveryTask(
        batchId: batch.id,
        volunteerId: 'VOL-CANCELER',
        volunteerName: 'Amit',
        volunteerPhone: '+91 90000 00000',
        delayFinalize: false,
      );

      expect(batch.assignedCourierId, equals('VOL-CANCELER'));

      // Volunteer cancels delivery
      service.cancelDeliveryTask(batch.id, 'Vehicle breakdown');
      expect(batch.status, equals(BatchStatus.claimed));
      expect(batch.assignedCourierId, isNull);
    });
  });

  group('UI Widget Tests for Real-Time Rescue', () {
    late SurplusBatch testBatch;

    setUp(() {
      testBatch = FoodRescueService.instance.listNewBatch(
        providerName: 'Royal Orchid Banquet',
        providerCategory: 'Banquet Hall',
        title: '60 Portions Paneer Pulao',
        category: 'Cooked Meals & Thalis',
        quantityPortions: 60,
        dietaryType: 'Pure Veg',
        temperatureCelsius: 64.0,
        packagingType: 'Aluminum Trays',
        pickupAddress: 'Old Airport Road, Bengaluru',
        location: const LatLng(12.9600, 77.6500),
        safeHours: 3,
      );

      FoodRescueService.instance.claimBatch(
        batchId: testBatch.id,
        ngoName: 'Mercy Children Care',
      );

      FoodRescueService.instance.startVolunteerAssignment(
        batchId: testBatch.id,
        volunteerId: 'VOL-TEST',
        volunteerName: 'Kavita Nair',
        volunteerPhone: '+91 97777 88888',
        autoFinalize: false,
      );
    });

    testWidgets('RescueAssignmentLoadingScreen renders tailored text for Provider', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RescueAssignmentLoadingScreen(
            batch: testBatch,
            role: RescueLoadingRole.provider,
            autoNavigateToTracking: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Volunteer Accepted — Connecting...'), findsOneWidget);
      expect(find.textContaining('60 servings'), findsOneWidget);
      expect(find.textContaining('Mercy Children Care'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('RescueAssignmentLoadingScreen renders tailored text for Receiver', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RescueAssignmentLoadingScreen(
            batch: testBatch,
            role: RescueLoadingRole.receiver,
            autoNavigateToTracking: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pickup Confirmed — Connecting Volunteer...'), findsOneWidget);
      expect(find.textContaining('Royal Orchid Banquet'), findsOneWidget);
    });

    testWidgets('SharedRescueTrackingPage renders map, safe timer, and provider action panel', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SharedRescueTrackingPage(
            batch: testBatch,
            role: RescueTrackingRole.provider,
          ),
        ),
      );
      await tester.pump();

      // Check header and status
      expect(find.textContaining('Live Delivery Tracking'), findsOneWidget);

      // Check OTP handover code for provider
      expect(find.text('Kitchen Handover PIN'), findsOneWidget);
      expect(find.text(testBatch.pickupOtp), findsOneWidget);

      // Check Rescue Details Card
      expect(find.text(testBatch.title), findsOneWidget);
      expect(find.text('Royal Orchid Banquet'), findsAtLeastNWidgets(1));
      expect(find.text('Mercy Children Care'), findsAtLeastNWidgets(1));
    });

    testWidgets('SharedRescueTrackingPage renders receiver action panel with delivery OTP', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SharedRescueTrackingPage(
            batch: testBatch,
            role: RescueTrackingRole.receiver,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Delivery Verification OTP'), findsOneWidget);
      expect(find.text(testBatch.deliveryOtp), findsOneWidget);
    });

    testWidgets('SharedRescueTrackingPage renders volunteer action controls', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FoodRescueService.instance.finalizeVolunteerAssignment(testBatch.id);

      await tester.pumpWidget(
        MaterialApp(
          home: SharedRescueTrackingPage(
            batch: testBatch,
            role: RescueTrackingRole.volunteer,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Volunteer Action Controls'), findsOneWidget);
      expect(find.text('Arrived at Pickup Dock'), findsOneWidget);
      expect(find.textContaining('Simulat'), findsOneWidget);
    });

    testWidgets('SharedRescueTrackingPage displays Pickup Confirmed banner and Continue to Delivery when pickedUp', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FoodRescueService.instance.finalizeVolunteerAssignment(testBatch.id);
      FoodRescueService.instance.updateTaskDeliveryStatus(testBatch.id, BatchStatus.arrivedAtPickup);
      FoodRescueService.instance.verifyPickupOtp(testBatch.id, testBatch.pickupOtp);

      await tester.pumpWidget(
        MaterialApp(
          home: SharedRescueTrackingPage(
            batch: testBatch,
            role: RescueTrackingRole.volunteer,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Pickup Confirmed'), findsOneWidget);
      expect(find.text('Continue to Delivery'), findsOneWidget);
    });

    testWidgets('SharedRescueTrackingPage displays completion summary when delivered', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FoodRescueService.instance.finalizeVolunteerAssignment(testBatch.id);
      FoodRescueService.instance.updateTaskDeliveryStatus(testBatch.id, BatchStatus.arrivedAtReceiver);
      FoodRescueService.instance.verifyDeliveryOtp(testBatch.id, testBatch.deliveryOtp);

      await tester.pumpWidget(
        MaterialApp(
          home: SharedRescueTrackingPage(
            batch: testBatch,
            role: RescueTrackingRole.volunteer,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Delivery Successfully Completed!'), findsOneWidget);
      expect(find.text('Portions'), findsOneWidget);
    });
  });
}
