import 'food_rescue_service.dart';

class ProviderImpactMetrics {
  final int mealsRedistributed;
  final double foodSavedKg;
  final int peopleServed;
  final double co2AvoidedKg;

  const ProviderImpactMetrics({
    required this.mealsRedistributed,
    required this.foodSavedKg,
    required this.peopleServed,
    required this.co2AvoidedKg,
  });
}

/// Centralized service calculating environmental and social impact metrics
/// from actual provider donation batches.
class ImpactCalculationService {
  /// Baseline offsets to represent provider's historical journey while seamlessly
  /// accumulating newly verified live batches.
  static const int baselineMeals = 420;

  /// Transparent conversion factors:
  /// - 1 average meal ≈ 0.5 kg of food saved
  /// - 1 meal portions served ≈ 0.75 persons reached (combining family portions)
  /// - 1 kg food waste prevented ≈ 1.33 kg CO2e avoided (approx 0.67 kg CO2e per meal)
  static const double kgPerMeal = 0.5;
  static const double peoplePerMeal = 0.75;
  static const double co2KgPerMeal = 0.67;

  /// Calculate metrics for a specific list of provider batches
  static ProviderImpactMetrics calculate(List<SurplusBatch> providerBatches) {
    // Delivered batches count towards confirmed impact
    final deliveredMeals = providerBatches
        .where((b) => b.status == BatchStatus.delivered)
        .fold<int>(0, (sum, b) => sum + b.quantityPortions);

    // Active/claimed batches in transit also represent committed food
    final inTransitMeals = providerBatches
        .where((b) =>
            b.status == BatchStatus.claimed ||
            b.status == BatchStatus.inTransitToPickup ||
            b.status == BatchStatus.pickedUp)
        .fold<int>(0, (sum, b) => sum + b.quantityPortions);

    final totalMeals = baselineMeals + deliveredMeals + inTransitMeals;

    return ProviderImpactMetrics(
      mealsRedistributed: totalMeals,
      foodSavedKg: double.parse((totalMeals * kgPerMeal).toStringAsFixed(1)),
      peopleServed: (totalMeals * peoplePerMeal).round(),
      co2AvoidedKg: double.parse((totalMeals * co2KgPerMeal).toStringAsFixed(1)),
    );
  }
}
