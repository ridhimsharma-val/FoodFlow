import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/food_rescue_service.dart';
import 'volunteer_accept_task_dialog.dart';
import 'volunteer_task_details_dialog.dart';

class VolunteerTasksPage extends StatefulWidget {
  final LatLng volunteerLocation;
  final String volunteerLocationName;
  final bool isAvailable;
  final ValueChanged<bool> onAvailabilityChanged;

  const VolunteerTasksPage({
    super.key,
    required this.volunteerLocation,
    required this.volunteerLocationName,
    required this.isAvailable,
    required this.onAvailabilityChanged,
  });

  @override
  State<VolunteerTasksPage> createState() => _VolunteerTasksPageState();
}

class _VolunteerTasksPageState extends State<VolunteerTasksPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'All'; // All, Nearby, Urgent, Today
  String _selectedSort = 'Nearest'; // Nearest, Most Urgent, Pickup Time
  static const Distance _distCalc = Distance();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double _getPickupDistance(LatLng target) {
    final m = _distCalc.as(LengthUnit.Meter, widget.volunteerLocation, target);
    return double.parse((m / 1000.0).toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final allTasks = FoodRescueService.instance.availableDeliveryTasks;

        // Apply filters
        var filtered = allTasks.where((b) {
          final q = _searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            final matchTitle = b.title.toLowerCase().contains(q);
            final matchProvider = b.providerName.toLowerCase().contains(q);
            final matchReceiver = (b.claimedByNgo ?? '').toLowerCase().contains(q);
            final matchAddress = b.pickupAddress.toLowerCase().contains(q);
            if (!matchTitle && !matchProvider && !matchReceiver && !matchAddress) {
              return false;
            }
          }

          final dist = _getPickupDistance(b.location);
          if (_selectedFilter == 'Nearby' && dist > 5.0) return false;
          if (_selectedFilter == 'Urgent' && b.remainingSafeTime.inMinutes > 120) return false;
          if (_selectedFilter == 'Today') {
            final now = DateTime.now();
            final isToday = b.cookedAt.year == now.year &&
                b.cookedAt.month == now.month &&
                b.cookedAt.day == now.day;
            if (!isToday) return false;
          }
          return true;
        }).toList();

        // Apply sorting
        if (_selectedSort == 'Nearest') {
          filtered.sort((a, b) => _getPickupDistance(a.location).compareTo(_getPickupDistance(b.location)));
        } else if (_selectedSort == 'Most Urgent') {
          filtered.sort((a, b) => a.remainingSafeTime.compareTo(b.remainingSafeTime));
        } else if (_selectedSort == 'Pickup Time') {
          filtered.sort((a, b) => a.cookedAt.compareTo(b.cookedAt));
        }

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available Tasks',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Delivery opportunities connecting donors with local shelters',
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Sort dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSort,
                              icon: const Icon(Icons.sort_rounded, size: 16, color: Color(0xFF64748B)),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              items: const [
                                DropdownMenuItem(value: 'Nearest', child: Text('Sort: Nearest')),
                                DropdownMenuItem(value: 'Most Urgent', child: Text('Sort: Most Urgent')),
                                DropdownMenuItem(value: 'Pickup Time', child: Text('Sort: Pickup Time')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedSort = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Search Bar
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFFFC107), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Filter Chips: All, Nearby, Urgent, Today
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', Icons.all_inclusive_rounded),
                          const SizedBox(width: 8),
                          _buildFilterChip('Nearby', Icons.near_me_rounded),
                          const SizedBox(width: 8),
                          _buildFilterChip('Urgent', Icons.priority_high_rounded),
                          const SizedBox(width: 8),
                          _buildFilterChip('Today', Icons.today_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Count row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${filtered.length} delivery ${filtered.length == 1 ? 'task' : 'tasks'} available',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            const Text('Live Dispatch', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Offline Banner (if volunteer toggled offline)
                    if (!widget.isAvailable) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFC107)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'You are currently offline. Toggle your status to "Available for Tasks" to accept deliveries.',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => widget.onAvailabilityChanged(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Go Online', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tasks List or Empty State
                    if (filtered.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text(
                              'No Claimed Rescues Ready for Dispatch',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Surplus food must first be claimed by an NGO receiver before a courier delivery task is created.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ...filtered.map((b) => _buildTaskDiscoveryCard(context, b)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFC107) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFFB45309) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFFB45309) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskDiscoveryCard(BuildContext context, SurplusBatch batch) {
    final pickupKm = _getPickupDistance(batch.location);
    final deliveryKm = 2.8;
    final totalKm = double.parse((pickupKm + deliveryKm).toStringAsFixed(1));
    final window = '7:00 PM – 8:00 PM';
    final remainingMinutes = batch.remainingSafeTime.inMinutes;
    final isUrgent = remainingMinutes <= 120 && remainingMinutes > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent ? const Color(0xFFFFC107) : const Color(0xFFE2E8F0),
          width: isUrgent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title, portions, and Urgent badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(batch.foodEmoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            batch.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUrgent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFFC107)),
                            ),
                            child: const Text(
                              '🚨 URGENT',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${batch.category} • ${batch.dietaryType}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${batch.quantityPortions} meals',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Provider Pickup & Receiver Delivery details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.store_rounded, size: 15, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Text('Provider: ${batch.providerName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                    const Spacer(),
                    Text('Pickup: $pickupKm km', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(width: 23),
                    Expanded(
                      child: Text('Location: ${batch.pickupAddress}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const Divider(height: 12, color: Color(0xFFE2E8F0)),
                Row(
                  children: [
                    const Icon(Icons.volunteer_activism_rounded, size: 15, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Text('Receiver: ${batch.claimedByNgo ?? 'Helping Hands NGO'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                    const Spacer(),
                    Text('Deliver: $deliveryKm km', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(width: 23),
                    Expanded(
                      child: Text('Location: ${batch.receiverDropoffAddress ?? 'Greater Noida'}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Total route, pickup window & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total route: $totalKm km • Est. 20 mins',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    'Pickup: $window',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      VolunteerTaskDetailsDialog.show(
                        context,
                        batch: batch,
                        pickupDistanceKm: pickupKm,
                        deliveryDistanceKm: deliveryKm,
                        totalRouteKm: totalKm,
                        pickupWindow: window,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('View Task', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      VolunteerAcceptTaskDialog.show(
                        context,
                        batch: batch,
                        pickupDistanceKm: pickupKm,
                        deliveryDistanceKm: deliveryKm,
                        totalRouteKm: totalKm,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: const Color(0xFF1E293B),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 14),
                    label: const Text('Start Pickup', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
