import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/food_rescue_service.dart';
import 'food_details_dialog.dart';
import 'claim_confirmation_dialog.dart';
import 'nearby_food_map_page.dart';

class BrowseFoodPage extends StatefulWidget {
  final LatLng receiverLocation;
  final String receiverLocationName;

  const BrowseFoodPage({
    super.key,
    required this.receiverLocation,
    required this.receiverLocationName,
  });

  @override
  State<BrowseFoodPage> createState() => _BrowseFoodPageState();
}

class _BrowseFoodPageState extends State<BrowseFoodPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'All'; // 'All', 'Veg', 'Non-Veg', 'Near Me'
  static const Distance _distCalc = Distance();

  double _getDistance(LatLng target) {
    final m = _distCalc.as(LengthUnit.Meter, widget.receiverLocation, target);
    return double.parse((m / 1000.0).toStringAsFixed(1));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final allAvailable = FoodRescueService.instance.availableBatches;

        // Apply Search & Filter
        final query = _searchCtrl.text.trim().toLowerCase();
        final filtered = allAvailable.where((batch) {
          // Only truly available food
          if (batch.status != BatchStatus.available) return false;

          // Dietary Filter
          if (_selectedFilter == 'Veg') {
            final diet = batch.dietaryType.toLowerCase();
            if (!diet.contains('veg') || diet.contains('non')) return false;
          } else if (_selectedFilter == 'Non-Veg') {
            final diet = batch.dietaryType.toLowerCase();
            if (!diet.contains('non') && !diet.contains('chicken') && !diet.contains('egg')) return false;
          } else if (_selectedFilter == 'Near Me') {
            final d = _getDistance(batch.location);
            if (d > 5.0) return false;
          }

          // Search Query
          if (query.isNotEmpty) {
            final matchTitle = batch.title.toLowerCase().contains(query);
            final matchProvider = batch.providerName.toLowerCase().contains(query);
            final matchAddress = batch.pickupAddress.toLowerCase().contains(query);
            final matchCategory = batch.category.toLowerCase().contains(query);
            return matchTitle || matchProvider || matchAddress || matchCategory;
          }

          return true;
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

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
                        // Page Title & Map View Action
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available Food',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Fresh surplus meals available for immediate shelter rescue',
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NearbyFoodMapPage(
                                      receiverLocation: widget.receiverLocation,
                                      receiverLocationName: widget.receiverLocationName,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFEF3C7),
                                foregroundColor: const Color(0xFF92400E),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: Color(0xFFFFC107)),
                                ),
                              ),
                              icon: const Icon(Icons.map_rounded, size: 16, color: Color(0xFFD97706)),
                              label: const Text('Map View', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Search Bar
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search food, location, or provider...',
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

                        // Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('All', Icons.all_inclusive_rounded),
                              const SizedBox(width: 8),
                              _buildFilterChip('Veg', Icons.eco_rounded),
                              const SizedBox(width: 8),
                              _buildFilterChip('Non-Veg', Icons.restaurant_rounded),
                              const SizedBox(width: 8),
                              _buildFilterChip('Near Me', Icons.near_me_rounded),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Count Label & Realtime Indicator
                        Row(
                          children: [
                            Text(
                              '${filtered.length} donations available',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.wifi_tethering_rounded, size: 12, color: Color(0xFF16A34A)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Real-Time Broadcast',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Results List or Empty State
                        if (filtered.isEmpty)
                          _buildEmptyState()
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isWide ? 2 : 1,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: isWide ? 1.55 : 1.3,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, idx) => _buildBrowseFoodCard(context, filtered[idx]),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected ? const Color(0xFF92400E) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12.5,
              color: isSelected ? const Color(0xFF92400E) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFFEF3C7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFFFFC107) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      showCheckmark: false,
      onSelected: (_) {
        setState(() {
          _selectedFilter = label;
        });
      },
    );
  }

  Widget _buildBrowseFoodCard(BuildContext context, SurplusBatch batch) {
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
                        '${batch.quantityPortions} servings • ${batch.category}',
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
                    '${batch.providerName} • $distKm km away',
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 44, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text(
            'Nothing available matching your search.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try clearing filters or search terms to see all surplus donations.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _selectedFilter = 'All';
              });
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFFC107)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear Filters', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
