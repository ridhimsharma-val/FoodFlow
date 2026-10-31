import 'dart:math' as math;

/// Configurable food types and their perishability factors (gamma).
enum FoodType {
  staple,
  normal,
  perishable,
  luxury;

  String get label => switch (this) {
    FoodType.staple => 'Staple (Grains/Bread)',
    FoodType.normal => 'Normal Surplus',
    FoodType.perishable => 'Highly Perishable (Cooked/Dairy)',
    FoodType.luxury => 'Luxury / Low Utility (Desserts)',
  };

  static FoodType fromString(String? val) {
    if (val == null) return FoodType.normal;
    final clean = val.trim().toLowerCase();
    if (clean.contains('staple') || clean.contains('grain') || clean.contains('bread') || clean.contains('ration')) {
      return FoodType.staple;
    }
    if (clean.contains('perish') || clean.contains('meat') || clean.contains('dairy') || clean.contains('cooked')) {
      return FoodType.perishable;
    }
    if (clean.contains('luxury') || clean.contains('dessert') || clean.contains('cake')) {
      return FoodType.luxury;
    }
    return FoodType.normal;
  }
}

/// Declared quality tiers based on handling, temperature control, and storage conditions.
enum QualityTier {
  tier1,
  tier2,
  tier3;

  String get label => switch (this) {
    QualityTier.tier1 => 'Tier 1 — Premium Surplus (Untouched)',
    QualityTier.tier2 => 'Tier 2 — Buffet Remnants (Temp Controlled)',
    QualityTier.tier3 => 'Tier 3 — Aesthetic Defects (Aesthetic)',
  };

  String get shortLabel => switch (this) {
    QualityTier.tier1 => 'Tier 1 (Premium)',
    QualityTier.tier2 => 'Tier 2 (Buffet)',
    QualityTier.tier3 => 'Tier 3 (Aesthetic)',
  };

  static QualityTier fromString(String? val) {
    if (val == null) return QualityTier.tier1;
    final clean = val.trim().toLowerCase();
    if (clean.contains('3') || clean.contains('aesthetic') || clean.contains('defect')) {
      return QualityTier.tier3;
    }
    if (clean.contains('2') || clean.contains('buffet') || clean.contains('remnant')) {
      return QualityTier.tier2;
    }
    return QualityTier.tier1;
  }
}

/// Centralized configuration for the Dynamic Pricing / Smart Markdown Pricing engine.
class PricingConfig {
  // Perishability exponents (gamma)
  final double stapleGamma;
  final double normalGamma;
  final double perishableGamma;
  final double luxuryGamma;

  // Quality multipliers (W_quality)
  final double tier1QualityMultiplier;
  final double tier2QualityMultiplier;
  final double tier3QualityMultiplier;

  // Quantity thresholds and multipliers (W_quantity)
  final int smallQuantityThreshold;
  final double smallQuantityMultiplier;
  final int mediumQuantityThreshold;
  final double mediumQuantityMultiplier;
  final int largeQuantityThreshold;
  final double largeQuantityMultiplier;
  final double clearKitchenMultiplier;

  const PricingConfig({
    this.stapleGamma = 0.5,
    this.normalGamma = 1.0,
    this.perishableGamma = 2.0,
    this.luxuryGamma = 2.0,
    this.tier1QualityMultiplier = 1.0,
    this.tier2QualityMultiplier = 0.7,
    this.tier3QualityMultiplier = 0.5,
    this.smallQuantityThreshold = 20,
    this.smallQuantityMultiplier = 1.0,
    this.mediumQuantityThreshold = 20,
    this.mediumQuantityMultiplier = 0.85,
    this.largeQuantityThreshold = 50,
    this.largeQuantityMultiplier = 0.70,
    this.clearKitchenMultiplier = 0.50,
  });

  /// Default singleton configuration
  static const PricingConfig defaultConfig = PricingConfig();

  double getGammaForFoodType(FoodType type) => switch (type) {
    FoodType.staple => stapleGamma,
    FoodType.normal => normalGamma,
    FoodType.perishable => perishableGamma,
    FoodType.luxury => luxuryGamma,
  };

  double getQualityMultiplier(QualityTier tier) => switch (tier) {
    QualityTier.tier1 => tier1QualityMultiplier,
    QualityTier.tier2 => tier2QualityMultiplier,
    QualityTier.tier3 => tier3QualityMultiplier,
  };

  double getQuantityMultiplier({
    required int quantity,
    required bool clearKitchen,
  }) {
    if (clearKitchen) {
      return clearKitchenMultiplier;
    }
    if (quantity >= largeQuantityThreshold) {
      return largeQuantityMultiplier;
    }
    if (quantity >= mediumQuantityThreshold) {
      return mediumQuantityMultiplier;
    }
    return smallQuantityMultiplier;
  }
}

/// Encapsulates the complete result of a dynamic markdown pricing calculation.
class DynamicPriceResult {
  final double currentPrice;
  final double totalPrice;
  final double basePrice;
  final double totalBasePrice;
  final double floorPrice;
  final double discountPercentage;
  final double youSave;
  final Duration timeRemaining;
  final double timeRemainingHours;
  final double qualityMultiplier;
  final double quantityMultiplier;
  final double perishabilityFactor;
  final double decayFactor;
  final bool isExpired;

  const DynamicPriceResult({
    required this.currentPrice,
    required this.totalPrice,
    required this.basePrice,
    required this.totalBasePrice,
    required this.floorPrice,
    required this.discountPercentage,
    required this.youSave,
    required this.timeRemaining,
    required this.timeRemainingHours,
    required this.qualityMultiplier,
    required this.quantityMultiplier,
    required this.perishabilityFactor,
    required this.decayFactor,
    required this.isExpired,
  });

  /// Numeric formatted string of unit price e.g. "25.00" or "25"
  String get formattedCurrentPrice {
    if (currentPrice % 1 == 0) {
      return '${currentPrice.toInt()}';
    }
    return currentPrice.toStringAsFixed(2);
  }

  /// Currency formatted string of unit price e.g. "₹25.00" or "₹25"
  String get currencyCurrentPrice => '₹$formattedCurrentPrice';

  /// Numeric formatted base unit price e.g. "50.00" or "50"
  String get formattedBasePrice {
    if (basePrice % 1 == 0) {
      return '${basePrice.toInt()}';
    }
    return basePrice.toStringAsFixed(2);
  }

  /// Currency formatted base unit price e.g. "₹50.00" or "₹50"
  String get currencyBasePrice => '₹$formattedBasePrice';

  /// Formatted total price e.g. "₹1,250"
  String get formattedTotalPrice {
    if (totalPrice % 1 == 0) {
      return '₹${totalPrice.toInt()}';
    }
    return '₹${totalPrice.toStringAsFixed(2)}';
  }

  /// Formatted total base price e.g. "₹2,500"
  String get formattedTotalBasePrice {
    if (totalBasePrice % 1 == 0) {
      return '₹${totalBasePrice.toInt()}';
    }
    return '₹${totalBasePrice.toStringAsFixed(2)}';
  }

  /// Formatted savings e.g. "₹1,250"
  String get formattedYouSave {
    if (youSave % 1 == 0) {
      return '₹${youSave.toInt()}';
    }
    return '₹${youSave.toStringAsFixed(2)}';
  }

  /// Formatted discount percentage badge e.g. "50% OFF"
  String get formattedDiscountBadge {
    if (isExpired) return 'EXPIRED';
    if (discountPercentage <= 0) return 'FULL VALUE';
    return '${discountPercentage.round()}% OFF';
  }

  double get discountPercent => discountPercentage;
  String get discountBadge => formattedDiscountBadge;
  bool get isFloorApplied => !isExpired && currentPrice == floorPrice;
  String get status => isExpired ? 'Expired' : 'Available';

  /// Fraction of safe shelf-life remaining (between 0.0 and 1.0)
  double get percentRemaining {
    if (isExpired) return 0.0;
    if (decayFactor > 0 && perishabilityFactor > 0) {
      return math.pow(decayFactor, 1.0 / perishabilityFactor).toDouble().clamp(0.0, 1.0);
    }
    return isExpired ? 0.0 : 1.0;
  }

  /// Formatted remaining countdown text with live ticking seconds or multi-day format
  String get formattedCountdown {
    if (isExpired) return 'Expired';
    final days = timeRemaining.inDays;
    final hours = timeRemaining.inHours % 24;
    final mins = timeRemaining.inMinutes.remainder(60);
    final secs = timeRemaining.inSeconds.remainder(60);

    if (timeRemaining.inHours >= 24) {
      return '${days}d ${hours}h ${mins}m';
    }
    if (timeRemaining.inHours > 0) {
      return '${timeRemaining.inHours}h ${mins}m ${secs}s';
    }
    if (mins > 0) {
      return '${mins}m ${secs}s';
    }
    return '${secs}s';
  }

  /// Compact countdown for small badges e.g. "1h 25m" or "2d 4h"
  String get compactCountdown {
    if (isExpired) return 'Expired';
    if (timeRemaining.inHours >= 24) {
      return '${timeRemaining.inDays}d ${timeRemaining.inHours % 24}h';
    }
    final hours = timeRemaining.inHours;
    final mins = timeRemaining.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    final secs = timeRemaining.inSeconds.remainder(60);
    return '${mins}m ${secs}s';
  }

  /// Urgency label based on time remaining to expiry
  String get urgencyBadge {
    if (isExpired) return 'Expired';
    if (timeRemaining.inMinutes <= 30) return 'Last Call';
    if (timeRemaining.inHours <= 1) return 'Final Hour';
    if (timeRemaining.inHours <= 2) return 'Urgent Rescue';
    return 'Active Markdown';
  }
}

/// Centralized pricing calculation engine.
///
/// Implements the exponential markdown decay formula:
/// P_final = max(P_floor, P_base * W_quality * W_quantity * (T_remaining / T_total)^gamma)
class DynamicPricingService {
  static PricingConfig config = PricingConfig.defaultConfig;

  /// Calculate the dynamic markdown price for a food surplus listing.
  ///
  /// [currentTime] can be provided explicitly for deterministic testing.
  static DynamicPriceResult calculateDynamicPrice({
    required double basePrice,
    required double floorPrice,
    int? quantity,
    int? quantityPortions,
    required DateTime safeUntil,
    DateTime? cookedAt,
    dynamic foodType = FoodType.normal,
    dynamic qualityTier = QualityTier.tier1,
    bool clearKitchen = false,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();

    final parsedFoodType = foodType is FoodType
        ? foodType
        : (foodType is String ? FoodType.fromString(foodType) : FoodType.normal);
    final parsedQualityTier = qualityTier is QualityTier
        ? qualityTier
        : (qualityTier is String ? QualityTier.fromString(qualityTier) : QualityTier.tier1);

    // 1. Calculate time remaining
    final diff = safeUntil.difference(now);
    final isExpired = diff.isNegative || diff == Duration.zero;

    final effectiveBasePrice = math.max(0.0, basePrice);
    final effectiveFloorPrice = math.max(0.0, math.min(floorPrice, effectiveBasePrice));
    final effectiveQuantity = math.max(1, quantity ?? quantityPortions ?? 1);

    if (isExpired) {
      return DynamicPriceResult(
        currentPrice: 0.0,
        totalPrice: 0.0,
        basePrice: effectiveBasePrice,
        totalBasePrice: effectiveBasePrice * effectiveQuantity,
        floorPrice: effectiveFloorPrice,
        discountPercentage: 0.0,
        youSave: 0.0,
        timeRemaining: Duration.zero,
        timeRemainingHours: 0.0,
        qualityMultiplier: config.getQualityMultiplier(parsedQualityTier),
        quantityMultiplier: config.getQuantityMultiplier(quantity: effectiveQuantity, clearKitchen: clearKitchen),
        perishabilityFactor: config.getGammaForFoodType(parsedFoodType),
        decayFactor: 0.0,
        isExpired: true,
      );
    }

    final double tRemainingHours = diff.inSeconds / 3600.0;

    // 2. Calculate total shelf-life window
    double tTotalHours;
    if (cookedAt != null && safeUntil.isAfter(cookedAt)) {
      tTotalHours = safeUntil.difference(cookedAt).inSeconds / 3600.0;
    } else {
      // Fallback: estimate 4 hours total shelf life if cookedAt is absent or equal to safeUntil
      tTotalHours = math.max(4.0, tRemainingHours);
    }

    // Ensure T_remaining does not exceed T_total
    final normalizedRatio = math.max(0.0, math.min(1.0, tRemainingHours / tTotalHours));

    // 3. Multipliers & Perishability factor (gamma)
    final double gamma = config.getGammaForFoodType(parsedFoodType);
    final double wQuality = config.getQualityMultiplier(parsedQualityTier);
    final double wQuantity = config.getQuantityMultiplier(
      quantity: effectiveQuantity,
      clearKitchen: clearKitchen,
    );

    // 4. Exponential Decay Factor: (T_remaining / T_total)^gamma
    final double decayFactor = math.pow(normalizedRatio, gamma).toDouble();

    // 5. Raw calculated price: P_base * W_quality * W_quantity * decayFactor
    final double calculatedPrice = effectiveBasePrice * wQuality * wQuantity * decayFactor;

    // 6. Enforce floor price: P_final = max(P_floor, calculatedPrice)
    // Also ensure final price never exceeds base price
    final double rawUnitPrice = math.min(
      effectiveBasePrice,
      math.max(effectiveFloorPrice, calculatedPrice),
    );
    final double roundedUnitPrice = (rawUnitPrice * 100).round() / 100.0;

    // 7. Savings & Discount Percentage
    final double totalBasePrice = (effectiveBasePrice * effectiveQuantity * 100).round() / 100.0;
    final double totalPrice = (roundedUnitPrice * effectiveQuantity * 100).round() / 100.0;
    final double youSave = math.max(0.0, totalBasePrice - totalPrice);
    final double discountPercentage = effectiveBasePrice > 0
        ? math.max(0.0, ((effectiveBasePrice - roundedUnitPrice) / effectiveBasePrice) * 100.0)
        : 0.0;

    return DynamicPriceResult(
      currentPrice: roundedUnitPrice,
      totalPrice: totalPrice,
      basePrice: effectiveBasePrice,
      totalBasePrice: totalBasePrice,
      floorPrice: effectiveFloorPrice,
      discountPercentage: (discountPercentage * 10).round() / 10.0,
      youSave: (youSave * 100).round() / 100.0,
      timeRemaining: diff,
      timeRemainingHours: (tRemainingHours * 100).round() / 100.0,
      qualityMultiplier: wQuality,
      quantityMultiplier: wQuantity,
      perishabilityFactor: gamma,
      decayFactor: decayFactor,
      isExpired: false,
    );
  }
}
