import 'package:flutter/material.dart';
import '../../services/food_rescue_service.dart';
import '../../services/impact_calculation_service.dart';
import 'live_claim_page.dart';

class FoodHistoryPage extends StatefulWidget {
  final String providerName;

  const FoodHistoryPage({super.key, required this.providerName});

  @override
  State<FoodHistoryPage> createState() => _FoodHistoryPageState();
}

class _FoodHistoryPageState extends State<FoodHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<SurplusBatch> _filterBatches(List<SurplusBatch> batches, int tabIndex) {
    switch (tabIndex) {
      case 1: // Posted / Available
        return batches.where((b) => b.status == BatchStatus.available).toList();
      case 2: // Claimed / In-Transit
        return batches
            .where((b) =>
                b.status == BatchStatus.claimed ||
                b.status == BatchStatus.inTransitToPickup ||
                b.status == BatchStatus.pickedUp)
            .toList();
      case 3: // Completed / Delivered
        return batches.where((b) => b.status == BatchStatus.delivered).toList();
      case 0: // All
      default:
        return batches;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final allBatches = FoodRescueService.instance.getBatchesForProvider(widget.providerName, todayOnly: false);
        final metrics = ImpactCalculationService.calculate(allBatches);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Food History',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E293B),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFFFFC107),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Posted'),
                Tab(text: 'Claimed'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: List.generate(4, (index) {
                    final filtered = _filterBatches(allBatches, index);
                    if (filtered.isEmpty) {
                      return _buildEmptyState(index);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) => _buildHistoryCard(filtered[idx]),
                    );
                  }),
                ),
              ),

              // Bottom Summary Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Meals Donated',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'All verified donations',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${metrics.mealsRedistributed} meals',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(SurplusBatch batch) {
    final statusBadge = _buildStatusBadge(batch.status);
    final timeStr = _formatDateTime(batch.cookedAt);

    return InkWell(
      onTap: () {
        if (batch.status != BatchStatus.available) {
          LiveClaimPage.open(context, batch);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Food visual container
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(batch.foodEmoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          batch.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          statusBadge,
                          if (batch.status != BatchStatus.delivered) ...[
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF64748B)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                              onSelected: (val) {
                                if (val == 'withdraw') {
                                  _confirmWithdraw(context, batch);
                                } else if (val == 'live') {
                                  LiveClaimPage.open(context, batch);
                                }
                              },
                              itemBuilder: (ctx) => [
                                if (batch.status != BatchStatus.available)
                                  const PopupMenuItem(
                                    value: 'live',
                                    child: Row(
                                      children: [
                                        Icon(Icons.track_changes_rounded, size: 16, color: Color(0xFF334155)),
                                        SizedBox(width: 8),
                                        Text('Track Claim', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
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
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${batch.quantityPortions} servings',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• $timeStr',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  if (batch.claimedByNgo != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Claimed by: ${batch.claimedByNgo}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmWithdraw(BuildContext context, SurplusBatch batch) async {
    final isClaimed = batch.status != BatchStatus.available;
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
            Expanded(
              child: Text(
                isClaimed ? 'Cancel & Withdraw Batch?' : 'Withdraw Listing?',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isClaimed
                          ? 'This batch is claimed. Withdrawing will cancel the claim and remove the batch.'
                          : 'This will immediately delist this surplus food batch from the network.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
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
            child: const Text('Keep', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: Text(isClaimed ? 'Cancel & Withdraw' : 'Withdraw Food'),
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
                        ? 'Batch "${batch.title}" withdrawn and deleted successfully.'
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

  Widget _buildEmptyState(int tabIndex) {
    final titles = ['No history yet', 'No active postings', 'No claimed food', 'No completed donations yet'];
    final descs = [
      'Surplus food posted will appear here with live lifecycle tracking.',
      'Post surplus food from the Post tab to make meals available.',
      'When an NGO claims your surplus meals, they will appear here.',
      'Pickups confirmed and distributed will be permanently logged here.'
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 36, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              titles[tabIndex],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              descs[tabIndex],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    final timeOnly = '$hour:$min $ampm';

    if (isToday) return 'Today, $timeOnly';
    return '${dt.day}/${dt.month}, $timeOnly';
  }
}
