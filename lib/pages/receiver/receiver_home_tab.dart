import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/food_rescue_service.dart';
import '../../services/matching_service.dart';
import 'food_details_dialog.dart';
import 'claim_confirmation_dialog.dart';

class ReceiverHomeTab extends StatelessWidget {
  final String receiverName;
  final String organizationName;
  final String location;
  final LatLng latLng;
  final VoidCallback onOpenBrowseTab;
  final VoidCallback onOpenMyClaimsTab;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final VoidCallback onDetectLocation;
  final VoidCallback? onSwitchRole;
  final VoidCallback? onOpenDrawer;

  const ReceiverHomeTab({
    super.key,
    required this.receiverName,
    required this.organizationName,
    required this.location,
    required this.latLng,
    required this.onOpenBrowseTab,
    required this.onOpenMyClaimsTab,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.onDetectLocation,
    this.onSwitchRole,
    this.onOpenDrawer,
  });

  static const Distance _distCalc = Distance();

  double _getDistance(LatLng target) {
    final m = _distCalc.as(LengthUnit.Meter, latLng, target);
    return double.parse((m / 1000.0).toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final availableBatches = FoodRescueService.instance.availableBatches;

        // Smart Recommendations
        final recommendations = ReceiverRecommendationService.getRecommendations(
          availableBatches: availableBatches,
          receiverLocation: latLng,
          maxResults: 2,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Cleaner, modern Top App Bar
                      _buildTopAppBar(context),
                      const SizedBox(height: 20),

                      // 2. Primary CTA: Find Available Food
                      _buildPrimaryCta(context, availableBatches.length),
                      const SizedBox(height: 26),

                      // 4. Recommended For You (Smart Suggestions)
                      if (recommendations.isNotEmpty) ...[
                        _buildRecommendedSection(context, recommendations),
                        const SizedBox(height: 28),
                      ],

                      // 5. Available Near You (Genuine Food Cards)
                      _buildAvailableNearYouHeader(context, availableBatches.length),
                      const SizedBox(height: 14),

                      if (FoodRescueService.instance.lastFetchError != null && availableBatches.isEmpty)
                        _buildErrorState()
                      else if (availableBatches.isEmpty)
                        _buildEmptyAvailableCard()
                      else
                        _buildFoodCardsGrid(context, availableBatches.take(4).toList(), isWide),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Top App Bar
  // ---------------------------------------------------------------------------
  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Food Flow logo placeholder
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.restaurant_rounded, color: Colors.black87, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Food Flow',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    'RELIEF & RESCUE PLATFORM',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right: Notification icon + Profile avatar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onOpenNotifications,
                tooltip: 'Notifications',
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1E293B), size: 20),
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFC107),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Profile avatar
              InkWell(
                onTap: onOpenProfile,
                borderRadius: BorderRadius.circular(22),
                child: Tooltip(
                  message: '$organizationName • ${location.isNotEmpty ? location : 'Receiver Location'}',
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFFFC107),
                    child: Text(
                      receiverName.isNotEmpty ? receiverName[0].toUpperCase() : 'R',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main CTA: Find Available Food
  // ---------------------------------------------------------------------------
  Widget _buildPrimaryCta(BuildContext context, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFC107), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC107).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFC107)),
            ),
            child: const Icon(Icons.search_rounded, color: Color(0xFFD97706), size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find Available Food',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count freshly cooked surplus batches ready for claim nearby.',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF78350F), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onOpenBrowseTab,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFFFFC107)),
            label: const Text(
              'Browse Food',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recommended For You
  // ---------------------------------------------------------------------------
  Widget _buildRecommendedSection(BuildContext context, List<RecommendedFood> recs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 20),
            SizedBox(width: 6),
            Text(
              'Recommended For You',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...recs.map((r) => _buildRecommendationCard(context, r)),
      ],
    );
  }

  Widget _buildRecommendationCard(BuildContext context, RecommendedFood rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(rec.batch.foodEmoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rec.batch.title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('⭐ Recommended', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${rec.distanceKm} km away • ${rec.batch.quantityPortions} meals • Pickup available',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              FoodDetailsDialog.show(
                context,
                batch: rec.batch,
                distanceKm: rec.distanceKm,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: const Color(0xFF1E293B),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View Food', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Available Near You Header
  // ---------------------------------------------------------------------------
  Widget _buildAvailableNearYouHeader(BuildContext context, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'Available Near You',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: onOpenBrowseTab,
          child: const Text(
            'View All →',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB45309),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Food Cards Grid / List
  // ---------------------------------------------------------------------------
  Widget _buildFoodCardsGrid(BuildContext context, List<SurplusBatch> batches, bool isWide) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 2 : 1,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: isWide ? 1.55 : 1.3,
      ),
      itemCount: batches.length,
      itemBuilder: (ctx, idx) => _buildFoodCard(context, batches[idx]),
    );
  }

  Widget _buildFoodCard(BuildContext context, SurplusBatch batch) {
    final distKm = _getDistance(batch.location);

    return InkWell(
      onTap: () {
        FoodDetailsDialog.show(
          context,
          batch: batch,
          distanceKm: distKm,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(batch.foodEmoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${batch.quantityPortions} servings • Cooked',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: batch.isExpired ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    batch.isExpired ? 'Expired' : 'Available',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: batch.isExpired ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Dynamic Markdown Price Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: batch.isExpired ? const Color(0xFFFEF2F2) : const Color(0xFFFEF9C3).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: batch.isExpired ? const Color(0xFFFCA5A5) : const Color(0xFFFFE082),
                ),
              ),
              child: Row(
                children: [
                  if (batch.isExpired) ...[
                    const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    const Text(
                      'Expired (₹0) — Unsafe for intake',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                    ),
                  ] else ...[
                    Text(
                      '₹${batch.dynamicPricing.formattedBasePrice}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                        decoration: TextDecoration.lineThrough,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '₹${batch.dynamicPricing.formattedCurrentPrice}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Text(
                      ' / portion',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        batch.dynamicPricing.formattedDiscountBadge,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${batch.providerName} • $distKm km',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  batch.isExpired ? Icons.warning_rounded : Icons.schedule_rounded,
                  size: 13,
                  color: batch.isExpired ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    batch.isExpired
                        ? 'Safe window passed'
                        : '⏳ ${batch.dynamicPricing.formattedCountdown} left ${batch.formatSafeUntilTarget()} · Live pricing',
                    style: TextStyle(
                      fontSize: 11,
                      color: batch.isExpired ? const Color(0xFFDC2626) : const Color(0xFFB45309),
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: batch.isExpired
                      ? null
                      : () {
                          ClaimConfirmationDialog.show(
                            context,
                            batch: batch,
                            distanceKm: distKm,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: const Color(0xFF1E293B),
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: const Size(64, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    batch.isExpired ? 'Expired' : 'Claim',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAvailableCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.soup_kitchen_outlined, size: 40, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text(
            'Nothing available nearby right now.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'New surplus food will appear here automatically.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => FoodRescueService.instance.initSupabaseSync('refresh'),
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFD97706)),
            label: const Text('Refresh', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFFC107)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFFEF4444)),
          const SizedBox(height: 12),
          const Text(
            'Unable to load nearby food listings.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF991B1B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check your network connection and try again.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C)),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => FoodRescueService.instance.initSupabaseSync('retry'),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
