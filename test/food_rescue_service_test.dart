import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:food_flow/services/food_rescue_service.dart';

void main() {
  group('FoodRescueService Lifecycle Tests', () {
    late FoodRescueService service;

    setUp(() {
      service = FoodRescueService.instance;
    });

    test('listNewBatch adds available batch with 4-digit pickup and delivery OTPs', () {
      final initialCount = service.batches.length;
      final batch = service.listNewBatch(
        providerName: 'Test Banquet Kitchen',
        providerCategory: 'Banquet Hall',
        title: '50 Portions Paneer Rice Bowl',
        category: 'Cooked Meals & Thalis',
        quantityPortions: 50,
        dietaryType: 'Pure Veg',
        temperatureCelsius: 67.5,
        packagingType: 'Sealed Foil Trays',
        pickupAddress: 'Test Road, Bengaluru',
        location: const LatLng(12.9784, 77.6408),
        safeHours: 3,
      );

      expect(service.batches.length, equals(initialCount + 1));
      expect(batch.status, equals(BatchStatus.available));
      expect(batch.pickupOtp.length, equals(4));
      expect(batch.deliveryOtp.length, equals(4));
      expect(service.availableBatches.contains(batch), isTrue);
    });

    test('claimBatch locks batch for NGO and dispatches volunteer courier', () {
      final batch = service.listNewBatch(
        providerName: 'Test Bakery',
        providerCategory: 'Bakery',
        title: '30 Bread Loaves',
        category: 'Bakery & Dry Ration',
        quantityPortions: 30,
        dietaryType: 'Eggless Veg',
        temperatureCelsius: 22.0,
        packagingType: 'Paper Bags',
        pickupAddress: 'CMH Road, Bengaluru',
        location: const LatLng(12.9710, 77.6320),
      );

      final claimSuccess = service.claimBatch(
        batchId: batch.id,
        ngoName: 'Asha Care Home',
        requestVolunteerCourier: true,
      );

      expect(claimSuccess, isTrue);
      expect(batch.status, equals(BatchStatus.claimed));
      expect(batch.claimedByNgo, equals('Asha Care Home'));
      expect(batch.assignedCourierName, contains('Volunteer Squad'));
      expect(batch.courierEtaMinutes, isNotNull);
    });

    test('Dual-OTP Handover flow: verifyPickupOtp then verifyDeliveryOtp completes rescue', () {
      final initialMeals = service.totalMealsRescued;

      final batch = service.listNewBatch(
        providerName: 'Grand Hotel Kitchen',
        providerCategory: 'Hotel',
        title: '40 Packed Dinners',
        category: 'Cooked Meals & Thalis',
        quantityPortions: 40,
        dietaryType: 'Pure Veg',
        temperatureCelsius: 66.0,
        packagingType: 'Insulated Boxes',
        pickupAddress: '100ft Rd, Indiranagar',
        location: const LatLng(12.9810, 77.6430),
      );

      service.claimBatch(
        batchId: batch.id,
        ngoName: 'Hope Shelter',
        requestVolunteerCourier: true,
      );

      // 1. Wrong OTP fails
      final wrongPickup = service.verifyPickupOtp(batch.id, '0000');
      expect(wrongPickup, isFalse);
      expect(batch.status, equals(BatchStatus.claimed));

      // 2. Correct Pickup OTP succeeds
      final pickupSuccess = service.verifyPickupOtp(batch.id, batch.pickupOtp);
      expect(pickupSuccess, isTrue);
      expect(batch.status, equals(BatchStatus.pickedUp));
      expect(batch.pickedUpAt, isNotNull);

      // 3. Wrong Delivery OTP fails
      final wrongDelivery = service.verifyDeliveryOtp(batch.id, '9999');
      expect(wrongDelivery, isFalse);
      expect(batch.status, equals(BatchStatus.pickedUp));

      // 4. Correct Delivery OTP succeeds and updates metrics
      final deliverySuccess = service.verifyDeliveryOtp(batch.id, batch.deliveryOtp);
      expect(deliverySuccess, isTrue);
      expect(batch.status, equals(BatchStatus.delivered));
      expect(batch.deliveredAt, isNotNull);

      expect(service.totalMealsRescued, equals(initialMeals + 40));
      expect(service.carbonDivertedKg, greaterThan(0));
    });

    test('SurplusBatch.toJson normalizes dietary_type and validates UUID for provider_id', () {
      final now = DateTime.now();
      final batch = SurplusBatch(
        id: 'BATCH-TEST-001',
        providerId: 'invalid-uuid-string',
        providerName: 'Test Kitchen',
        providerCategory: 'Banquet',
        location: const LatLng(12.9784, 77.6408),
        title: 'Test Dish',
        category: 'Cooked Meals',
        quantityPortions: 25,
        dietaryType: 'Vegetarian', // Should normalize to 'Pure Veg'
        cookedAt: now,
        safeUntil: now.add(const Duration(hours: 4)),
        temperatureCelsius: 65.0,
        packagingType: 'Foil Boxes',
        pickupAddress: 'Test Location',
        pickupOtp: '1234',
        deliveryOtp: '5678',
      );

      final json = batch.toJson();
      // 'Vegetarian' must normalize to 'Pure Veg' to meet PostgreSQL check constraint
      expect(json['dietary_type'], equals('Pure Veg'));
      // Invalid UUID must be excluded so it doesn't fail foreign key checks
      expect(json.containsKey('provider_id'), isFalse);

      final batchWithUuid = SurplusBatch(
        id: 'BATCH-TEST-002',
        providerId: 'a1111111-1111-1111-1111-111111111111',
        providerName: 'Test Kitchen',
        providerCategory: 'Banquet',
        location: const LatLng(12.9784, 77.6408),
        title: 'Test Dish',
        category: 'Cooked Meals',
        quantityPortions: 25,
        dietaryType: 'Vegan',
        cookedAt: now,
        safeUntil: now.add(const Duration(hours: 4)),
        temperatureCelsius: 65.0,
        packagingType: 'Foil Boxes',
        pickupAddress: 'Test Location',
        pickupOtp: '1234',
        deliveryOtp: '5678',
      );

      final jsonWithUuid = batchWithUuid.toJson();
      expect(jsonWithUuid['provider_id'], equals('a1111111-1111-1111-1111-111111111111'));
      expect(jsonWithUuid['dietary_type'], equals('Vegan'));
      // Cooked and safe timestamps must serialize with UTC 'Z' suffix
      expect((jsonWithUuid['cooked_at'] as String).endsWith('Z'), isTrue);
      expect((jsonWithUuid['safe_until'] as String).endsWith('Z'), isTrue);
    });

    test('SurplusBatch remainingSafeTime accurately reflects safeHours without timezone shift', () {
      final batch = service.listNewBatch(
        providerName: 'Test Timezone Kitchen',
        providerCategory: 'Kitchen',
        title: 'Fresh Pulao',
        category: 'Cooked Meals',
        quantityPortions: 30,
        dietaryType: 'Pure Veg',
        temperatureCelsius: 65.0,
        packagingType: 'Boxes',
        pickupAddress: 'Test St',
        location: const LatLng(12.9784, 77.6408),
        safeHours: 4,
      );

      final remaining = batch.remainingSafeTime;
      // Remaining safe time must be approximately 4 hours (between 3h 58m and 4h 0m), never 9+ hours
      expect(remaining.inHours, inInclusiveRange(3, 4));
      expect(remaining.inMinutes, greaterThanOrEqualTo(238));
      expect(remaining.inMinutes, lessThanOrEqualTo(241));
    });

    test('Batch is visible to Receiver on list, but ONLY visible to Volunteer AFTER claimed by Receiver', () {
      // 1. Provider lists food
      final batch = service.listNewBatch(
        providerName: 'Highway Dhaba',
        providerCategory: 'Dhaba',
        title: '60 Portions Rajma Chawal',
        category: 'Cooked Meals',
        quantityPortions: 60,
        dietaryType: 'Pure Veg',
        temperatureCelsius: 68.0,
        packagingType: 'Thermal Cambros',
        pickupAddress: 'NH-44 Highway Dock',
        location: const LatLng(12.9784, 77.6408),
        safeHours: 4,
      );

      // 2. Visible to Receiver in availableBatches
      expect(service.availableBatches.any((b) => b.id == batch.id), isTrue);

      // 3. MUST NOT be visible to Volunteer yet!
      expect(service.availableDeliveryTasks.any((b) => b.id == batch.id), isFalse);

      // 4. NGO Receiver claims the batch
      final claimed = service.claimBatch(
        batchId: batch.id,
        ngoName: 'Mission Food NGO',
      );
      expect(claimed, isTrue);

      // 5. No longer in availableBatches for other receivers
      expect(service.availableBatches.any((b) => b.id == batch.id), isFalse);

      // 6. NOW it MUST appear in availableDeliveryTasks for volunteers!
      expect(service.availableDeliveryTasks.any((b) => b.id == batch.id), isTrue);
    });
  });
}

