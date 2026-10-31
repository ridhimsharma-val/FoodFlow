import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:food_flow/services/dynamic_pricing_service.dart';
import 'package:food_flow/services/food_rescue_service.dart';

void main() {
  group('DynamicPricingService Unit Tests', () {
    final now = DateTime(2026, 9, 10, 12, 0); // 12:00 PM
    final cookedAt = DateTime(2026, 9, 10, 10, 0); // 10:00 AM (total 4h window)
    final safeUntil = DateTime(2026, 9, 10, 14, 0); // 2:00 PM

    test('Fresh listing (T_rem == T_total): receives 1.0 time decay factor', () {
      final res = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 20.0,
        foodType: 'normal',
        qualityTier: 'tier1',
        quantityPortions: 10, // < 20, weight 1.0
        clearKitchen: false,
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: cookedAt, // At listing time
      );

      // P = 100 * 1.0 * 1.0 * (1.0)^1.0 = 100.0
      expect(res.currentPrice, equals(100.0));
      expect(res.isExpired, isFalse);
      expect(res.discountPercent, equals(0.0));
      expect(res.formattedDiscountBadge, equals('FULL VALUE'));
    });

    test('Half-life linear decay (T_rem/T_total = 0.5, gamma = 1.0)', () {
      final res = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 20.0,
        foodType: 'normal', // gamma = 1.0
        qualityTier: 'tier1', // 1.0
        quantityPortions: 10, // 1.0
        clearKitchen: false,
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: now, // 12:00 PM is exactly 2h of 4h left -> 0.5
      );

      // P = 100 * 1.0 * 1.0 * (0.5)^1.0 = 50.0
      expect(res.currentPrice, equals(50.0));
      expect(res.discountPercent, equals(50.0));
      expect(res.formattedDiscountBadge, equals('50% OFF'));
    });

    test('Half-life perishable decay (gamma = 2.0 -> (0.5)^2 = 0.25)', () {
      final res = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 10.0,
        foodType: 'perishable', // gamma = 2.0
        qualityTier: 'tier1',
        quantityPortions: 10,
        clearKitchen: false,
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: now, // 0.5 time remaining
      );

      // P = 100 * 1.0 * 1.0 * (0.5)^2.0 = 25.0
      expect(res.currentPrice, equals(25.0));
      expect(res.discountPercent, equals(75.0));
      expect(res.formattedDiscountBadge, equals('75% OFF'));
    });

    test('Half-life staple decay (gamma = 0.5 -> sqrt(0.5) approx 0.7071)', () {
      final res = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 10.0,
        foodType: 'staple', // gamma = 0.5
        qualityTier: 'tier1',
        quantityPortions: 10,
        clearKitchen: false,
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: now, // 0.5 time remaining
      );

      // P = 100 * 1.0 * 1.0 * sqrt(0.5) = 70.7106...
      expect(res.currentPrice, closeTo(70.71, 0.05));
    });

    test('Quality tiers: Tier 1 (1.0x), Tier 2 (0.7x), Tier 3 (0.5x)', () {
      final tier1 = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 10.0,
        foodType: 'normal',
        qualityTier: 'tier1',
        quantityPortions: 10,
        clearKitchen: false,
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: cookedAt,
      );
      expect(tier1.currentPrice, equals(100.0));

      final tier2 = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 10.0,
        foodType: 'normal',
        qualityTier: 'tier2',
        quantityPortions: 10,
        clearKitchen: false,
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: cookedAt,
      );
      expect(tier2.currentPrice, equals(70.0));

      final tier3 = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 10.0,
        foodType: 'normal',
        qualityTier: 'tier3',
        quantityPortions: 10,
        clearKitchen: false,
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: cookedAt,
      );
      expect(tier3.currentPrice, equals(50.0));
    });

    test('Quantity volume tiers: <20 (1.0x), 20-49 (0.85x), >=50 (0.70x)', () {
      final qtySmall = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 10.0,
        foodType: 'normal',
        qualityTier: 'tier1',
        quantityPortions: 15,
        clearKitchen: false,
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: cookedAt,
      );
      expect(qtySmall.currentPrice, equals(100.0));

      final qtyMed = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 10.0,
        foodType: 'normal',
        qualityTier: 'tier1',
        quantityPortions: 25,
        clearKitchen: false,
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: cookedAt,
      );
      expect(qtyMed.currentPrice, equals(85.0));

      final qtyLarge = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 10.0,
        foodType: 'normal',
        qualityTier: 'tier1',
        quantityPortions: 50,
        clearKitchen: false,
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: cookedAt,
      );
      expect(qtyLarge.currentPrice, equals(70.0));
    });

    test('Clear the Kitchen: overrides quantity multiplier to 0.50x', () {
      final clear = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 10.0,
        foodType: 'normal',
        qualityTier: 'tier1',
        quantityPortions: 10, // normally 1.0x
        clearKitchen: true, // overrides to 0.5x
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: cookedAt,
      );
      expect(clear.currentPrice, equals(50.0));
    });

    test('Floor Price Protection: Price cannot fall below P_floor while safe', () {
      final nearExpiry = cookedAt.add(const Duration(hours: 3, minutes: 55)); // 5 mins left
      final res = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 20.0,
        foodType: 'perishable', // rapid decay
        qualityTier: 'tier3', // 0.5x
        quantityPortions: 50, // 0.7x
        clearKitchen: true, // 0.5x
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: nearExpiry,
      );

      // Decayed value would be < 1.0, but floor protection clamps it to 20.0
      expect(res.currentPrice, equals(20.0));
      expect(res.isFloorApplied, isTrue);
      expect(res.isExpired, isFalse);
    });

    test('Expiry Safety Protocol: T_rem <= 0 results in Expired / 0.0 Rs', () {
      final expiredTime = safeUntil.add(const Duration(minutes: 1));
      final res = DynamicPricingService.calculateDynamicPrice(
        basePrice: 100.0,
        floorPrice: 20.0,
        foodType: 'normal',
        qualityTier: 'tier1',
        quantityPortions: 10,
        clearKitchen: false,
        cookedAt: cookedAt,
        safeUntil: safeUntil,
        currentTime: expiredTime,
      );

      expect(res.isExpired, isTrue);
      expect(res.currentPrice, equals(0.0));
      expect(res.discountBadge, equals('EXPIRED'));
      expect(res.status, equals('Expired'));
    });
  });

  group('FoodRescueService Dynamic Pricing Integration', () {
    test('listNewBatch correctly sets dynamic pricing fields and calculates on read', () {
      final service = FoodRescueService.instance;
      final batch = service.listNewBatch(
        providerName: 'Taj Residency Banquet',
        providerCategory: 'Luxury Hotel',
        title: 'Chicken Dum Biryani',
        category: 'Cooked Meals',
        quantityPortions: 60,
        dietaryType: 'Non-Veg',
        packagingType: 'Insulated Hot Box',
        temperatureCelsius: 68.0,
        pickupAddress: 'MG Road, Bengaluru',
        location: const LatLng(12.9716, 77.5946),
        basePrice: 120.0,
        floorPrice: 25.0,
        foodType: 'perishable',
        qualityTier: 'tier1',
        clearKitchen: false,
        safeHours: 4,
      );

      expect(batch.basePrice, equals(120.0));
      expect(batch.floorPrice, equals(25.0));
      expect(batch.foodType, equals('perishable'));
      expect(batch.qualityTier, equals('tier1'));

      final pricing = batch.dynamicPricing;
      expect(pricing.isExpired, isFalse);
      expect(pricing.currentPrice, greaterThanOrEqualTo(25.0));
    });

    test('claimBatch permanently locks the dynamic price into batch record', () {
      final service = FoodRescueService.instance;
      final batch = service.listNewBatch(
        providerName: 'Green Park Cafeteria',
        providerCategory: 'Corporate Cafeteria',
        title: 'Mixed Vegetable Pulao',
        category: 'Cooked Meals',
        quantityPortions: 40,
        dietaryType: 'Pure Veg',
        packagingType: 'Food-Grade Containers',
        temperatureCelsius: 65.0,
        pickupAddress: 'Whitefield, Bengaluru',
        location: const LatLng(12.9698, 77.7499),
        basePrice: 80.0,
        floorPrice: 15.0,
        foodType: 'normal',
        qualityTier: 'tier2',
        clearKitchen: false,
        safeHours: 3,
      );

      final dynamicPriceBefore = batch.dynamicPricing.currentPrice;
      expect(batch.lockedUnitPrice, isNull);
      expect(batch.lockedTotalPrice, isNull);

      final success = service.claimBatch(
        batchId: batch.id,
        ngoName: 'Robin Hood Relief NGO',
        claimedByNgoId: 'ngo-999',
      );

      expect(success, isTrue);
      expect(batch.status, equals(BatchStatus.claimed));
      expect(batch.lockedUnitPrice, isNotNull);
      expect(batch.lockedTotalPrice, isNotNull);
      expect(batch.lockedUnitPrice, closeTo(dynamicPriceBefore, 0.5));
      expect(batch.lockedTotalPrice, equals(batch.lockedUnitPrice! * batch.quantityPortions));
      expect(batch.discountAtPurchase, isNotNull);
    });

    test('claimBatch rejects expired batches to safeguard food safety', () {
      final service = FoodRescueService.instance;
      final batch = service.listNewBatch(
        providerName: 'Midnight Diner',
        providerCategory: 'Restaurant',
        title: 'Egg Fried Rice',
        category: 'Cooked Meals',
        quantityPortions: 20,
        dietaryType: 'Non-Veg',
        packagingType: 'Standard Containers',
        temperatureCelsius: 60.0,
        pickupAddress: 'Koramangala, Bengaluru',
        location: const LatLng(12.9352, 77.6245),
        basePrice: 60.0,
        floorPrice: 10.0,
        cookedAt: DateTime.now().subtract(const Duration(hours: 5)),
        safeUntil: DateTime.now().subtract(const Duration(hours: 1)), // expired 1 hour ago
      );

      expect(batch.isExpired, isTrue);

      final claimSuccess = service.claimBatch(
        batchId: batch.id,
        ngoName: 'City Shelter Trust',
      );

      expect(claimSuccess, isFalse);
      expect(batch.status, equals(BatchStatus.expired));
    });

    test('Dynamic price drops progressively as time left diminishes', () {
      final base = 100.0;
      final floor = 10.0;
      final cooked = DateTime(2026, 9, 10, 8, 0); // 8:00 AM
      final safeUntil = DateTime(2026, 9, 10, 12, 0); // 12:00 PM (4h total)

      // 4 hours left (fresh)
      final at8am = DynamicPricingService.calculateDynamicPrice(
        basePrice: base,
        floorPrice: floor,
        cookedAt: cooked,
        safeUntil: safeUntil,
        foodType: 'normal',
        currentTime: DateTime(2026, 9, 10, 8, 0),
      );

      // 3 hours left (75% time remaining)
      final at9am = DynamicPricingService.calculateDynamicPrice(
        basePrice: base,
        floorPrice: floor,
        cookedAt: cooked,
        safeUntil: safeUntil,
        foodType: 'normal',
        currentTime: DateTime(2026, 9, 10, 9, 0),
      );

      // 2 hours left (50% time remaining)
      final at10am = DynamicPricingService.calculateDynamicPrice(
        basePrice: base,
        floorPrice: floor,
        cookedAt: cooked,
        safeUntil: safeUntil,
        foodType: 'normal',
        currentTime: DateTime(2026, 9, 10, 10, 0),
      );

      // 1 hour left (25% time remaining)
      final at11am = DynamicPricingService.calculateDynamicPrice(
        basePrice: base,
        floorPrice: floor,
        cookedAt: cooked,
        safeUntil: safeUntil,
        foodType: 'normal',
        currentTime: DateTime(2026, 9, 10, 11, 0),
      );

      // 15 mins left (6.25% time remaining) -> hits floor price
      final at1145am = DynamicPricingService.calculateDynamicPrice(
        basePrice: base,
        floorPrice: floor,
        cookedAt: cooked,
        safeUntil: safeUntil,
        foodType: 'normal',
        currentTime: DateTime(2026, 9, 10, 11, 45),
      );

      // Expiry -> ₹0
      final at12pm = DynamicPricingService.calculateDynamicPrice(
        basePrice: base,
        floorPrice: floor,
        cookedAt: cooked,
        safeUntil: safeUntil,
        foodType: 'normal',
        currentTime: DateTime(2026, 9, 10, 12, 0),
      );

      expect(at8am.currentPrice, equals(100.0));
      expect(at9am.currentPrice, equals(75.0));
      expect(at10am.currentPrice, equals(50.0));
      expect(at11am.currentPrice, equals(25.0));
      expect(at1145am.currentPrice, equals(10.0)); // floor price
      expect(at1145am.isFloorApplied, isTrue);
      expect(at12pm.currentPrice, equals(0.0));
      expect(at12pm.isExpired, isTrue);

      // Monotonic decay verification
      expect(at8am.currentPrice > at9am.currentPrice, isTrue);
      expect(at9am.currentPrice > at10am.currentPrice, isTrue);
      expect(at10am.currentPrice > at11am.currentPrice, isTrue);
      expect(at11am.currentPrice > at1145am.currentPrice, isTrue);
    });

    test('Live formatted countdown displays hours, minutes, and seconds', () {
      final now = DateTime(2026, 9, 10, 10, 0, 0);
      final safeUntil = DateTime(2026, 9, 10, 12, 35, 18); // 2h 35m 18s

      final res = DynamicPricingService.calculateDynamicPrice(
        basePrice: 50.0,
        floorPrice: 10.0,
        cookedAt: now.subtract(const Duration(hours: 1)),
        safeUntil: safeUntil,
        currentTime: now,
      );

      expect(res.formattedCountdown, equals('2h 35m 18s'));
      expect(res.compactCountdown, equals('2h 35m'));
      expect(res.formattedCurrentPrice, isNot(startsWith('₹')));
      expect(res.currencyCurrentPrice, startsWith('₹'));
    });

    test('Live formatted countdown displays multi-day breakdown for shelf-life >= 24h', () {
      final now = DateTime(2026, 9, 10, 10, 0, 0);
      final safeUntil = now.add(const Duration(days: 6, hours: 18, minutes: 25, seconds: 40));

      final res = DynamicPricingService.calculateDynamicPrice(
        basePrice: 50.0,
        floorPrice: 10.0,
        cookedAt: now.subtract(const Duration(hours: 1)),
        safeUntil: safeUntil,
        currentTime: now,
      );

      expect(res.formattedCountdown, equals('6d 18h 25m'));
      expect(res.compactCountdown, equals('6d 18h'));
    });
  });
}
