import 'package:flutter/material.dart';
import '../../services/food_rescue_service.dart';
import '../../services/impact_calculation_service.dart';

class ImpactPage extends StatelessWidget {
  final String providerName;

  const ImpactPage({super.key, required this.providerName});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final providerBatches = FoodRescueService.instance.getBatchesForProvider(providerName, todayOnly: false);
        final metrics = ImpactCalculationService.calculate(providerBatches);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Your Impact',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heading & Subtitle
                    Text(
                      'Making Every Meal Count',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Real-time cumulative statistics powered by your kitchen surplus donations across Food Flow.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 24),

                    // 4 Major Cards Grid
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isWide = constraints.maxWidth > 550;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isWide ? 2 : 1,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: isWide ? 2.2 : 2.6,
                          children: [
                            _buildImpactCard(
                              number: '${metrics.mealsRedistributed}',
                              label: 'Meals Redistributed',
                              icon: Icons.dinner_dining_rounded,
                              iconColor: const Color(0xFFB45309),
                              bgColor: const Color(0xFFFEF3C7),
                              borderHighlight: const Color(0xFFFFC107),
                            ),
                            _buildImpactCard(
                              number: '${metrics.foodSavedKg} kg',
                              label: 'Food Saved',
                              icon: Icons.scale_rounded,
                              iconColor: const Color(0xFF047857),
                              bgColor: const Color(0xFFD1FAE5),
                              borderHighlight: const Color(0xFF10B981),
                            ),
                            _buildImpactCard(
                              number: '${metrics.peopleServed}',
                              label: 'People Served',
                              icon: Icons.people_alt_rounded,
                              iconColor: const Color(0xFF1D4ED8),
                              bgColor: const Color(0xFFDBEAFE),
                              borderHighlight: const Color(0xFF3B82F6),
                            ),
                            _buildImpactCard(
                              number: '${metrics.co2AvoidedKg} kg',
                              label: 'Estimated CO₂ Avoided',
                              icon: Icons.eco_rounded,
                              iconColor: const Color(0xFF0F766E),
                              bgColor: const Color(0xFFCCFBF1),
                              borderHighlight: const Color(0xFF14B8A6),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // "A Greener Tomorrow" Section
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFD97706), size: 24),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Text(
                                  'A Greener Tomorrow',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Your generosity helps reduce food waste, feed communities and build a healthier planet.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF334155),
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 14),
                          const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Impact estimates are modeled from certified surplus food redistribution baselines (~0.5 kg per plate, 1.33 kg CO₂e avoided per kg food saved).',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImpactCard({
    required String number,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderHighlight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
