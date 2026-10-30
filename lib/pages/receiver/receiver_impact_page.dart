import 'package:flutter/material.dart';
import '../../services/food_rescue_service.dart';
import '../../services/impact_calculation_service.dart';

class ReceiverImpactPage extends StatelessWidget {
  const ReceiverImpactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final allBatches = FoodRescueService.instance.batches;
        final metrics = ImpactCalculationService.calculate(allBatches);

        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Text(
                      'Your Impact',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Real metrics from your community food redistribution efforts',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),

                    // "A Greener Tomorrow" Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFFC107)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.eco_rounded, color: Color(0xFFD97706), size: 28),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'A Greener Tomorrow',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Your efforts help rescue surplus food and get it to people who need it.',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF78350F), height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // 4 Big Data-Driven Impact Metric Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;
                        final cardWidth = isNarrow ? (constraints.maxWidth - 14) / 2 : (constraints.maxWidth - 42) / 4;

                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _buildImpactMetricCard(
                              value: '${metrics.mealsRedistributed}',
                              label: 'Meals Redistributed',
                              subtitle: 'Good food channeled to shelters',
                              icon: Icons.soup_kitchen_rounded,
                              iconBg: const Color(0xFFFEF3C7),
                              iconColor: const Color(0xFFD97706),
                              width: cardWidth,
                            ),
                            _buildImpactMetricCard(
                              value: '${metrics.foodSavedKg} kg',
                              label: 'Food Saved',
                              subtitle: 'Kept away from city landfills',
                              icon: Icons.inventory_2_rounded,
                              iconBg: const Color(0xFFDCFCE7),
                              iconColor: const Color(0xFF16A34A),
                              width: cardWidth,
                            ),
                            _buildImpactMetricCard(
                              value: '${metrics.peopleServed}',
                              label: 'People Served',
                              subtitle: 'Nourished through local NGOs',
                              icon: Icons.people_alt_rounded,
                              iconBg: const Color(0xFFDBEAFE),
                              iconColor: const Color(0xFF2563EB),
                              width: cardWidth,
                            ),
                            _buildImpactMetricCard(
                              value: '${metrics.co2AvoidedKg} kg',
                              label: 'Estimated CO₂ Avoided',
                              subtitle: 'Methane emission prevention',
                              icon: Icons.cloud_done_rounded,
                              iconBg: const Color(0xFFF3E8FF),
                              iconColor: const Color(0xFF9333EA),
                              width: cardWidth,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // Beneficiary Community Breakdown Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.volunteer_activism_rounded, color: Color(0xFFD97706), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Community Relief Breakdown',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildBreakdownRow('Homeless & Night Shelters', '180 meals (43%)', const Color(0xFFFFC107)),
                          const SizedBox(height: 8),
                          _buildBreakdownRow('Children Education Homes', '140 meals (33%)', const Color(0xFF10B981)),
                          const SizedBox(height: 8),
                          _buildBreakdownRow('Senior Citizen Support Centers', '100 meals (24%)', const Color(0xFF3B82F6)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Calculation Methodology Transparency Notice
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Impact Estimation Methodology: Calculated on Food Flow verified intake batches. Baseline assumes 1 average meal ≈ 0.5 kg food saved and 1 kg food waste averted avoids ~1.33 kg CO₂e equivalent.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.4),
                            ),
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

  Widget _buildImpactMetricCard({
    required String value,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, Color barColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: label.contains('43%') ? 0.43 : (label.contains('33%') ? 0.33 : 0.24),
            minHeight: 6,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
