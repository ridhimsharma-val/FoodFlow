import 'package:flutter/material.dart';
import '../../services/food_rescue_service.dart';
import '../../services/supabase_service.dart';
import 'my_claim_details_page.dart';

class MyClaimsPage extends StatefulWidget {
  final VoidCallback onOpenBrowse;

  const MyClaimsPage({
    super.key,
    required this.onOpenBrowse,
  });

  @override
  State<MyClaimsPage> createState() => _MyClaimsPageState();
}

class _MyClaimsPageState extends State<MyClaimsPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final meta = user?.userMetadata ?? {};
    final receiverOrg = (meta['organization_name'] ??
            meta['full_name'] ??
            meta['name'] ??
            (user?.email?.split('@').first ?? 'Relief Center'))
        .toString()
        .trim()
        .toLowerCase();

    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final allBatches = FoodRescueService.instance.batches;

        // Filter batches claimed genuinely by this receiver
        final myClaims = allBatches.where((b) {
          if (b.status == BatchStatus.available) return false;
          if (b.claimedByNgoId != null && user != null && b.claimedByNgoId == user.id) return true;
          if (b.claimedByNgo != null && receiverOrg.isNotEmpty && b.claimedByNgo!.toLowerCase().contains(receiverOrg)) return true;
          return false;
        }).toList();

        final activeClaims = myClaims
            .where((b) =>
                b.status == BatchStatus.claimed ||
                b.status == BatchStatus.volunteerAssigning ||
                b.status == BatchStatus.inTransitToPickup ||
                b.status == BatchStatus.arrivedAtPickup ||
                b.status == BatchStatus.pickedUp ||
                b.status == BatchStatus.inTransit ||
                b.status == BatchStatus.arrivedAtReceiver)
            .toList();

        final completedClaims = myClaims.where((b) => b.status == BatchStatus.delivered).toList();

        final totalMealsClaimed = myClaims.fold<int>(0, (sum, b) => sum + b.quantityPortions);
        final displayTotalMeals = totalMealsClaimed;

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // Top Header Bar
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Claims',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Track active pickups, transit couriers, and completed distribution',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    // Tabs: All, Claimed, Completed
                    TabBar(
                      controller: _tabCtrl,
                      labelColor: const Color(0xFF1E293B),
                      unselectedLabelColor: const Color(0xFF64748B),
                      indicatorColor: const Color(0xFFFFC107),
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      tabs: [
                        Tab(text: 'All (${myClaims.length})'),
                        Tab(text: 'Claimed (${activeClaims.length})'),
                        Tab(text: 'Completed (${completedClaims.length})'),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildClaimsList(context, myClaims),
                    _buildClaimsList(context, activeClaims),
                    _buildClaimsList(context, completedClaims),
                  ],
                ),
              ),

              // Bottom Total Meals Claimed Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  border: Border(top: BorderSide(color: Color(0xFFFFC107))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.volunteer_activism_rounded, color: Color(0xFFB45309), size: 22),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Meals Claimed',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                        ),
                        Text(
                          'Redistribution Impact to Date',
                          style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFC107)),
                      ),
                      child: Text(
                        '$displayTotalMeals meals',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClaimsList(BuildContext context, List<SurplusBatch> list) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 14),
              const Text(
                "You haven't claimed any food yet.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              const Text(
                'No worries — available surplus food will appear in Browse.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: widget.onOpenBrowse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Browse Available Food', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) => _buildClaimCard(context, list[idx]),
    );
  }

  Widget _buildClaimCard(BuildContext context, SurplusBatch batch) {
    final isDelivered = batch.status == BatchStatus.delivered;
    final isPickedUp = batch.status == BatchStatus.pickedUp;
    final inTransit = batch.status == BatchStatus.inTransitToPickup;

    String statusText = 'Claimed';
    Color statusBg = const Color(0xFFFEF3C7);
    Color statusColor = const Color(0xFFB45309);

    if (isDelivered) {
      statusText = 'Completed';
      statusBg = const Color(0xFFDCFCE7);
      statusColor = const Color(0xFF16A34A);
    } else if (isPickedUp) {
      statusText = 'Handed Over';
      statusBg = const Color(0xFFDBEAFE);
      statusColor = const Color(0xFF2563EB);
    } else if (inTransit) {
      statusText = 'Pickup Confirmed';
      statusBg = const Color(0xFFE0E7FF);
      statusColor = const Color(0xFF4338CA);
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MyClaimDetailsPage(batch: batch),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(batch.foodEmoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          batch.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${batch.quantityPortions} servings • ${batch.providerName}',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (!isDelivered) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFFC107)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.key_rounded, size: 10, color: Color(0xFFB45309)),
                              const SizedBox(width: 3),
                              Text(
                                'Delivery OTP: ${batch.deliveryOtp}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB45309),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isDelivered ? 'Delivered successfully' : 'Pickup 7:00 PM – 8:00 PM',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}
