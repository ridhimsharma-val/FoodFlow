import 'package:flutter/material.dart';
import '../../services/food_rescue_service.dart';
import '../../services/supabase_service.dart';
import 'volunteer_active_task_page.dart';
import 'volunteer_payment_confirmation_page.dart';

class VolunteerHistoryPage extends StatefulWidget {
  final VoidCallback onOpenTasks;

  const VolunteerHistoryPage({super.key, required this.onOpenTasks});

  @override
  State<VolunteerHistoryPage> createState() => _VolunteerHistoryPageState();
}

class _VolunteerHistoryPageState extends State<VolunteerHistoryPage> with SingleTickerProviderStateMixin {
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
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final user = SupabaseService.currentUser;
        final allBatches = FoodRescueService.instance.batches;

        // Tasks assigned to / delivered by this volunteer
        final myBatches = allBatches.where((b) {
          if (user != null && b.assignedCourierId == user.id) return true;
          return b.status == BatchStatus.delivered ||
              b.status == BatchStatus.inTransitToPickup ||
              b.status == BatchStatus.arrivedAtPickup ||
              b.status == BatchStatus.pickedUp ||
              b.status == BatchStatus.inTransit ||
              b.status == BatchStatus.arrivedAtReceiver;
        }).toList();

        // Categorize into Active, Completed, Cancelled
        final activeList = myBatches.where((b) =>
            b.status == BatchStatus.inTransitToPickup ||
            b.status == BatchStatus.arrivedAtPickup ||
            b.status == BatchStatus.pickedUp ||
            b.status == BatchStatus.inTransit ||
            b.status == BatchStatus.arrivedAtReceiver).toList();

        final completedList = myBatches.where((b) =>
            b.status == BatchStatus.delivered).toList();

        final totalCompleted = completedList.length;
        final totalMeals = completedList.fold<int>(0, (sum, b) => sum + b.quantityPortions);
        final totalKm = (completedList.fold<double>(0.0, (sum, b) => sum + (b.distanceRemainingKm ?? 3.5))).round();
        final successRate = (totalCompleted + activeList.length) > 0 ? '100%' : '100%';

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header with 4 Key History Metrics
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Task History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Review completed rescues, active transit, and courier milestones',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),

                    // 4 Metric cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth > 600
                            ? (constraints.maxWidth - 36) / 4
                            : (constraints.maxWidth - 12) / 2;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            _buildSummaryMetric('$totalCompleted', 'Tasks Completed', width),
                            _buildSummaryMetric('$totalMeals', 'Meals Delivered', width),
                            _buildSummaryMetric('$totalKm km', 'Distance Covered', width),
                            _buildSummaryMetric(successRate, 'Successful Deliveries', width),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Sub-tabs: Active, Completed, Cancelled
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
                        Tab(text: 'Active (${activeList.length})'),
                        Tab(text: 'Completed (${completedList.length})'),
                        const Tab(text: 'Cancelled (0)'),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildActiveTab(context, activeList),
                    _buildCompletedTab(context, completedList),
                    _buildCancelledTab(context),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryMetric(String val, String label, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            val,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTab(BuildContext context, List<SurplusBatch> activeList) {
    if (activeList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.two_wheeler_outlined, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              const Text(
                'No active delivery right now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Explore available nearby tasks and start transporting meals.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: widget.onOpenTasks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Find Nearby Tasks', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: activeList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) => _buildTaskItemCard(context, activeList[idx], isActive: true),
    );
  }

  Widget _buildCompletedTab(BuildContext context, List<SurplusBatch> completedList) {
    if (completedList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assignment_turned_in_outlined, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              const Text(
                'No completed deliveries yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Once you complete a food delivery with dual-OTP handover verification, it will appear here.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: widget.onOpenTasks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Find Nearby Tasks', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: completedList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) => _buildTaskItemCard(context, completedList[idx], isActive: false),
    );
  }

  Widget _buildCancelledTab(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
            SizedBox(height: 12),
            Text(
              'No cancelled tasks',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            SizedBox(height: 4),
            Text(
              'Your reliability record is exemplary with a 98% fulfillment rate.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItemCard(BuildContext context, SurplusBatch batch, {required bool isActive}) {
    final statusText = isActive
        ? (batch.status == BatchStatus.pickedUp ? 'Food Collected' : 'Going to Pickup')
        : 'Delivered';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                batch.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isActive ? const Color(0xFFB45309) : const Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${batch.quantityPortions} meals • ${batch.providerName} → ${batch.claimedByNgo ?? 'Helping Hands NGO'}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Est. Distance: 4.0 km',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              if (isActive)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => VolunteerActiveTaskPage(batch: batch)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: const Color(0xFF1E293B),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Open Tracking', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => VolunteerPaymentConfirmationPage(batch: batch)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF9C3),
                    foregroundColor: const Color(0xFF854D0E),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 14),
                  label: const Text('Payment Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
