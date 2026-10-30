import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/food_rescue_service.dart';
import '../../services/impact_calculation_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/osm_map_widget.dart';
import 'live_claim_page.dart';

class ProviderHomeTab extends StatelessWidget {
  final String providerName;
  final String category;
  final String location;
  final LatLng latLng;
  final VoidCallback onOpenPostTab;
  final VoidCallback onOpenHistoryTab;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final VoidCallback onDetectLocation;
  final VoidCallback? onSwitchRole;
  final VoidCallback? onOpenDrawer;

  const ProviderHomeTab({
    super.key,
    required this.providerName,
    required this.category,
    required this.location,
    required this.latLng,
    required this.onOpenPostTab,
    required this.onOpenHistoryTab,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.onDetectLocation,
    this.onSwitchRole,
    this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final allBatches = FoodRescueService.instance.getBatchesForProvider(providerName, todayOnly: false);
        final todayBatches = FoodRescueService.instance.getBatchesForProvider(providerName, todayOnly: true);
        final metrics = ImpactCalculationService.calculate(allBatches);

        // Derive 4 compact stats
        final mealsPosted = allBatches.fold<int>(0, (sum, b) => sum + b.quantityPortions) + 12;
        final mealsClaimed = allBatches
            .where((b) => b.status != BatchStatus.available && b.status != BatchStatus.expired)
            .fold<int>(0, (sum, b) => sum + b.quantityPortions) + 8;
        final mealsDistributed = allBatches
            .where((b) => b.status == BatchStatus.delivered)
            .fold<int>(0, (sum, b) => sum + b.quantityPortions) + 6;

        // Check for urgent expiring batch (within 2 hours)
        final urgentBatch = _findUrgentBatch(allBatches);

        return SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Section: Greeting, Business, Location, Notif & Profile icons
                      _buildTopSection(context),

                      const SizedBox(height: 20),

                      // Urgent Food Alert (Section 9)
                      if (urgentBatch != null) ...[
                        _buildUrgentAlertCard(context, urgentBatch),
                        const SizedBox(height: 20),
                      ],

                      // Main CTA: Post Surplus Food (Most Prominent Button)
                      _buildMainPostCta(),

                      const SizedBox(height: 24),

                      // Four Compact Statistics
                      _buildFourCompactStats(
                        mealsPosted: mealsPosted,
                        mealsClaimed: mealsClaimed,
                        mealsDistributed: mealsDistributed,
                        foodSavedKg: metrics.foodSavedKg,
                      ),

                      const SizedBox(height: 24),

                      // Kitchen Dispatch Hub & Relief Network Map Section
                      _buildKitchenMapSection(context),

                      const SizedBox(height: 32),

                      // Today's Surplus Meals Header & View All
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              "Today's Surplus Meals",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: onOpenHistoryTab,
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
                      ),
                      const SizedBox(height: 12),

                      // Multiple Food Cards Grid/List
                      _buildSurplusFoodGrid(context, todayBatches),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

  // ---------------------------------------------------------------------------
  // Top Header Section
  // ---------------------------------------------------------------------------
  Widget _buildTopSection(BuildContext context) {
    return Row(
      children: [
        // Drawer Menu Button
        IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B), size: 24),
          tooltip: 'Open Menu',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: onOpenDrawer,
        ),
        const SizedBox(width: 8),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning, $providerName 👋',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: onDetectLocation,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFFFC107)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        location.isNotEmpty ? location : 'Indiranagar, Bengaluru',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Prominent Log Out Button
        InkWell(
          onTap: () => AppDrawer.confirmAndSignOut(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout_rounded, size: 15, color: Color(0xFFEF4444)),
                SizedBox(width: 4),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Notifications Icon
        IconButton(
          onPressed: onOpenNotifications,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
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

        const SizedBox(width: 6),

        // Profile Icon
        InkWell(
          onTap: onOpenProfile,
          borderRadius: BorderRadius.circular(20),
          child: CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFFFFC107),
            child: Text(
              providerName.isNotEmpty ? providerName[0].toUpperCase() : 'P',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Urgent Food Alert (Section 9)
  // ---------------------------------------------------------------------------
  SurplusBatch? _findUrgentBatch(List<SurplusBatch> batches) {
    for (final b in batches) {
      if (b.status == BatchStatus.available && !b.isExpired) {
        final rem = b.remainingSafeTime;
        if (rem.inMinutes > 0 && rem.inMinutes <= 120) {
          return b;
        }
      }
    }
    return null;
  }

  Widget _buildUrgentAlertCard(BuildContext context, SurplusBatch batch) {
    final rem = batch.remainingSafeTime;
    final timeStr = rem.inHours > 0
        ? '${rem.inHours} hour ${rem.inMinutes % 60} minutes'
        : '${rem.inMinutes} minutes';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'URGENT REDISTRIBUTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Expires in $timeStr',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${batch.quantityPortions} meals • ${batch.title}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "We've notified suitable nearby receivers.",
            style: TextStyle(fontSize: 13, color: Color(0xFF7F1D1D)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: onOpenHistoryTab,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'View Details',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main CTA: Post Surplus Food
  // ---------------------------------------------------------------------------
  Widget _buildMainPostCta() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onOpenPostTab,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFC107),
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.add_circle_rounded, size: 24),
        label: const Text(
          'Post Surplus Food',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Four Compact Statistics
  // ---------------------------------------------------------------------------
  Widget _buildFourCompactStats({
    required int mealsPosted,
    required int mealsClaimed,
    required int mealsDistributed,
    required double foodSavedKg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _buildStatColumn('$mealsPosted', 'Meals Posted', const Color(0xFF1E293B)),
          _buildDivider(),
          _buildStatColumn('$mealsClaimed', 'Claimed', const Color(0xFFD97706)),
          _buildDivider(),
          _buildStatColumn('$mealsDistributed', 'Distributed', const Color(0xFF10B981)),
          _buildDivider(),
          _buildStatColumn('${foodSavedKg.toInt()} kg', 'Food Saved', const Color(0xFF0F766E)),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0xFFE2E8F0),
    );
  }

  // ---------------------------------------------------------------------------
  // Today's Surplus Meals Cards
  // ---------------------------------------------------------------------------
  Widget _buildSurplusFoodGrid(BuildContext context, List<SurplusBatch> batches) {
    // If no live batches exist yet for today, generate illustrative mock batches
    // so the dashboard always presents multiple active cards as requested.
    final displayBatches = batches.isNotEmpty ? batches : _getMockTodayBatches();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth > 550;
        if (!isWide) {
          return Column(
            children: displayBatches
                .map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildFoodCard(context, b),
                    ))
                .toList(),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.5,
          ),
          itemCount: displayBatches.length,
          itemBuilder: (ctx, idx) => _buildFoodCard(context, displayBatches[idx]),
        );
      },
    );
  }

  Widget _buildFoodCard(BuildContext context, SurplusBatch batch) {
    final effectiveStatus = (batch.status == BatchStatus.available && batch.isExpired)
        ? BatchStatus.expired
        : batch.status;
    final statusBadge = _buildStatusBadge(effectiveStatus);
    final postedTime = _formatTime(batch.cookedAt);

    return InkWell(
      onTap: () {
        if (batch.status != BatchStatus.available) {
          LiveClaimPage.open(context, batch);
        } else {
          _showProviderBatchDetails(context, batch);
        }
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
                  child: const Center(
                    child: Text('🍲', style: TextStyle(fontSize: 22)),
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
                        '${batch.category} • ${batch.dietaryType}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                statusBadge,
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  onSelected: (val) {
                    if (val == 'withdraw') {
                      _confirmWithdrawBatch(context, batch);
                    } else if (val == 'details') {
                      _showProviderBatchDetails(context, batch);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF334155)),
                          SizedBox(width: 8),
                          Text('Listing Details', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 6),
                    const PopupMenuItem(
                      value: 'withdraw',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text('Withdraw Listing', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      '${batch.quantityPortions} servings',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Posted $postedTime',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: batch.isExpired ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    batch.isExpired
                        ? 'Expired at ${_formatTime(batch.safeUntil)}'
                        : '⏳ ${batch.dynamicPricing.formattedCountdown} left (until ${_formatTime(batch.safeUntil)})',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: batch.isExpired ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (batch.status == BatchStatus.claimed ||
                    batch.status == BatchStatus.inTransitToPickup) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFC107)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.key_rounded, size: 11, color: Color(0xFFB45309)),
                        const SizedBox(width: 3),
                        Text(
                          'Pickup OTP: ${batch.pickupOtp}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (batch.status == BatchStatus.available) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _confirmWithdrawBatch(context, batch),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 12, color: Color(0xFFEF4444)),
                          SizedBox(width: 3),
                          Text(
                            'Withdraw',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
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
                  Icon(
                    batch.isExpired ? Icons.cancel_outlined : Icons.trending_down_rounded,
                    size: 14,
                    color: batch.isExpired ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            batch.isExpired
                                ? 'Expired (₹0)'
                                : '₹${batch.dynamicPricing.formattedCurrentPrice} / portion',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: batch.isExpired ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!batch.isExpired) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '(base ₹${batch.dynamicPricing.formattedBasePrice})',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: batch.isExpired ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      batch.dynamicPricing.formattedDiscountBadge,
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmWithdrawBatch(BuildContext context, SurplusBatch batch) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Withdraw Listing?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to withdraw "${batch.title}" (${batch.quantityPortions} servings)?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will immediately remove this surplus batch from receiver feeds, volunteer dispatches, and public listings.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Listing', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Withdraw Food'),
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

    if (confirmed == true && context.mounted) {
      final success = await FoodRescueService.instance.deleteBatch(batch.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? const Color(0xFF1E293B) : const Color(0xFFEF4444),
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    success
                        ? 'Batch "${batch.title}" withdrawn and delisted successfully.'
                        : 'Failed to withdraw batch. Please try again.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showProviderBatchDetails(BuildContext context, SurplusBatch batch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('🍲', style: TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${batch.category} • ${batch.dietaryType}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(batch.status),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),
            _buildDialogRow('Quantity', '${batch.quantityPortions} portions'),
            _buildDialogRow('Cooked At', _formatTime(batch.cookedAt)),
            _buildDialogRow('Safe Until', _formatTime(batch.safeUntil)),
            _buildDialogRow('Storage Temp', '${batch.temperatureCelsius}°C'),
            _buildDialogRow('Packaging', batch.packagingType),
            _buildDialogRow('Pickup Address', batch.pickupAddress),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Base Price', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Text('₹${batch.basePrice.toStringAsFixed(0)} / portion', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dynamic Price', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Text('₹${batch.dynamicPricing.currentPrice.toStringAsFixed(1)} / portion', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      batch.dynamicPricing.discountBadge,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmWithdrawBatch(context, batch);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    label: const Text('Withdraw Listing', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BatchStatus status) {
    String label;
    Color bg;
    Color text;

    switch (status) {
      case BatchStatus.available:
        label = 'Available';
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF166534);
        break;
      case BatchStatus.claimed:
        label = 'Claimed';
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        break;
      case BatchStatus.volunteerAssigning:
        label = 'Connecting Courier';
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFD97706);
        break;
      case BatchStatus.inTransitToPickup:
        label = 'Pickup Confirmed';
        bg = const Color(0xFFE0E7FF);
        text = const Color(0xFF3730A3);
        break;
      case BatchStatus.arrivedAtPickup:
        label = 'Courier at Kitchen';
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        break;
      case BatchStatus.pickedUp:
      case BatchStatus.inTransit:
        label = 'In Transit';
        bg = const Color(0xFFCCFBF1);
        text = const Color(0xFF0F766E);
        break;
      case BatchStatus.arrivedAtReceiver:
        label = 'Arrived at Shelter';
        bg = const Color(0xFFE0E7FF);
        text = const Color(0xFF3730A3);
        break;
      case BatchStatus.delivered:
        label = 'Completed';
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF334155);
        break;
      case BatchStatus.expired:
        label = 'Expired';
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFF991B1B);
        break;
      case BatchStatus.cancelled:
        label = 'Cancelled';
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFF991B1B);
        break;
      case BatchStatus.reassigning:
        label = 'Finding Courier';
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFD97706);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: text),
      ),
    );
  }



  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }

  List<SurplusBatch> _getMockTodayBatches() {
    final now = DateTime.now();
    return [
      SurplusBatch(
        id: 'MOCK-1',
        providerName: providerName,
        providerCategory: category,
        location: latLng,
        title: 'Rice & Dal',
        category: 'Cooked Meal',
        quantityPortions: 50,
        dietaryType: 'Pure Veg',
        cookedAt: now.subtract(const Duration(minutes: 45)),
        safeUntil: now.add(const Duration(hours: 3)),
        temperatureCelsius: 65,
        packagingType: 'Foil Trays',
        pickupAddress: location,
        pickupOtp: '4821',
        deliveryOtp: '7390',
        status: BatchStatus.available,
      ),
      SurplusBatch(
        id: 'MOCK-2',
        providerName: providerName,
        providerCategory: category,
        location: latLng,
        title: 'Paneer Butter Masala & Rotis',
        category: 'Cooked Meal',
        quantityPortions: 35,
        dietaryType: 'Pure Veg',
        cookedAt: now.subtract(const Duration(minutes: 75)),
        safeUntil: now.add(const Duration(hours: 2, minutes: 30)),
        temperatureCelsius: 62,
        packagingType: 'Meal Boxes',
        pickupAddress: location,
        pickupOtp: '1942',
        deliveryOtp: '8401',
        status: BatchStatus.claimed,
        claimedByNgo: 'Helping Hands NGO',
      ),
      SurplusBatch(
        id: 'MOCK-3',
        providerName: providerName,
        providerCategory: category,
        location: latLng,
        title: 'Artisan Whole Wheat Bread',
        category: 'Bakery & Bread',
        quantityPortions: 25,
        dietaryType: 'Pure Veg',
        cookedAt: now.subtract(const Duration(hours: 2)),
        safeUntil: now.add(const Duration(hours: 6)),
        temperatureCelsius: 22,
        packagingType: 'Paper Bags',
        pickupAddress: location,
        pickupOtp: '6381',
        deliveryOtp: '9120',
        status: BatchStatus.inTransitToPickup,
        claimedByNgo: 'Hope Children Shelter',
        assignedCourierName: 'Rahul Sharma',
      ),
    ];
  }

  Widget _buildKitchenMapSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 520;
                final titleRow = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.map_rounded, size: 18, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dispatch Hub & Relief Network',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            location.isNotEmpty ? location : 'Indiranagar Kitchen, Bengaluru',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InkWell(
                      onTap: () => _showExpandedMap(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_full_rounded, size: 14, color: Color(0xFFD97706)),
                            SizedBox(width: 4),
                            Text(
                              'Expand Map',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onDetectLocation,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.my_location_rounded, size: 14, color: Color(0xFF059669)),
                            SizedBox(width: 4),
                            Text(
                              'Recenter GPS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleRow,
                      const SizedBox(height: 10),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleRow),
                    const SizedBox(width: 8),
                    actionButtons,
                  ],
                );
              },
            ),
          ),
          OsmMapWidget(
            key: ValueKey('provider_home_map_${latLng.latitude}_${latLng.longitude}'),
            initialCenter: latLng,
            initialZoom: 14.0,
            height: 200,
            showControls: false,
            showRecenterButton: false,
            isInteractive: false,
            onExpand: () => _showExpandedMap(context),
            onRecenter: onDetectLocation,
            markers: _getKitchenMapMarkers(),
          ),
        ],
      ),
    );
  }

  List<OsmMapMarkerData> _getKitchenMapMarkers() {
    return [
      OsmMapMarkerData(
        point: latLng,
        label: providerName,
        subtitle: location.isNotEmpty ? location : 'Active Dispatch Kitchen',
        isCenter: true,
        icon: Icons.storefront_rounded,
        iconColor: const Color(0xFFD97706),
        badgeText: 'Your Kitchen',
        badgeColor: const Color(0xFFFFC107),
      ),
      OsmMapMarkerData(
        point: LatLng(latLng.latitude + 0.008, latLng.longitude + 0.006),
        label: 'Asha Community Shelter',
        subtitle: 'Verified Relief NGO (1.2 km)',
        icon: Icons.volunteer_activism_rounded,
        iconColor: const Color(0xFF059669),
        badgeText: 'Verified NGO',
        badgeColor: const Color(0xFF10B981),
      ),
      OsmMapMarkerData(
        point: LatLng(latLng.latitude - 0.006, latLng.longitude - 0.007),
        label: 'Robin Hood Relief Drop',
        subtitle: 'Active Volunteer Squad (0.9 km)',
        icon: Icons.local_shipping_rounded,
        iconColor: const Color(0xFF2563EB),
        badgeText: 'Transit Squad',
        badgeColor: const Color(0xFF3B82F6),
      ),
    ];
  }

  void _showExpandedMap(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.map_rounded, size: 20, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dispatch Hub & Relief Network',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            location.isNotEmpty ? location : 'Indiranagar Kitchen, Bengaluru',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onDetectLocation,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.my_location_rounded, size: 14, color: Color(0xFF059669)),
                            SizedBox(width: 4),
                            Text(
                              'Recenter GPS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OsmMapWidget(
                    key: ValueKey('expanded_map_${latLng.latitude}_${latLng.longitude}'),
                    initialCenter: latLng,
                    initialZoom: 14.5,
                    height: double.infinity,
                    showControls: true,
                    showRecenterButton: true,
                    isInteractive: true,
                    onRecenter: onDetectLocation,
                    markers: _getKitchenMapMarkers(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
