import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/food_rescue_service.dart';
import '../../widgets/osm_map_widget.dart';
import 'food_details_dialog.dart';

class NearbyFoodMapPage extends StatefulWidget {
  final LatLng receiverLocation;
  final String receiverLocationName;

  const NearbyFoodMapPage({
    super.key,
    required this.receiverLocation,
    required this.receiverLocationName,
  });

  @override
  State<NearbyFoodMapPage> createState() => _NearbyFoodMapPageState();
}

class _NearbyFoodMapPageState extends State<NearbyFoodMapPage> {
  SurplusBatch? _selectedBatch;
  static const Distance _distCalc = Distance();

  double _getDistance(LatLng target) {
    final m = _distCalc.as(LengthUnit.Meter, widget.receiverLocation, target);
    return double.parse((m / 1000.0).toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final availableBatches = FoodRescueService.instance.availableBatches;

        // Auto-select first batch if none selected yet
        if (_selectedBatch == null && availableBatches.isNotEmpty) {
          _selectedBatch = availableBatches.first;
        }

        final markers = <OsmMapMarkerData>[
          // Receiver hub marker
          OsmMapMarkerData(
            point: widget.receiverLocation,
            label: 'Your Intake Shelter Hub',
            subtitle: widget.receiverLocationName,
            iconColor: const Color(0xFF2563EB),
            icon: Icons.volunteer_activism_rounded,
            isCenter: true,
          ),
          // Food donor markers
          ...availableBatches.map((b) {
            final d = _getDistance(b.location);
            return OsmMapMarkerData(
              point: b.location,
              label: b.title,
              subtitle: '${b.providerName} • $d km',
              iconColor: const Color(0xFFD97706),
              icon: Icons.restaurant_rounded,
            );
          }),
        ];

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Nearby Food Map',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFC107)),
                    ),
                    child: Text(
                      '${availableBatches.length} Available Nearby',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              // OpenStreetMap Canvas
              OsmMapWidget(
                key: ValueKey('nearby_map_${widget.receiverLocation.latitude}_${widget.receiverLocation.longitude}'),
                initialCenter: widget.receiverLocation,
                initialZoom: 13.8,
                markers: markers,
                showControls: true,
                showRecenterButton: true,
                onTap: (point) {
                  if (availableBatches.isNotEmpty) {
                    final sorted = List<SurplusBatch>.from(availableBatches);
                    sorted.sort((a, b) {
                      final da = _distCalc.as(LengthUnit.Meter, a.location, point);
                      final db = _distCalc.as(LengthUnit.Meter, b.location, point);
                      return da.compareTo(db);
                    });
                    setState(() {
                      _selectedBatch = sorted.first;
                    });
                  }
                },
              ),

              // Bottom Card Preview when a food batch is selected
              if (_selectedBatch != null)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(_selectedBatch!.foodEmoji, style: const TextStyle(fontSize: 24)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedBatch!.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_selectedBatch!.quantityPortions} servings • ${_getDistance(_selectedBatch!.location)} km',
                                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Available',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFD97706)),
                                const SizedBox(width: 4),
                                const Text(
                                  'Pickup 7:00 PM – 8:00 PM',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                                ),
                                const Spacer(),
                                Text(
                                  _selectedBatch!.providerName,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: ElevatedButton(
                                onPressed: () {
                                  FoodDetailsDialog.show(
                                    context,
                                    batch: _selectedBatch!,
                                    distanceKm: _getDistance(_selectedBatch!.location),
                                    onClaimSuccess: () => setState(() => _selectedBatch = null),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFC107),
                                  foregroundColor: const Color(0xFF1E293B),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text(
                                  'View Food',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
