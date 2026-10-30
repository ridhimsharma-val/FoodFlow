import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/open_route_service.dart';

class OsmMapMarkerData {
  final LatLng point;
  final String label;
  final String? subtitle;
  final String? badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color iconColor;
  final bool isCenter;

  const OsmMapMarkerData({
    required this.point,
    required this.label,
    this.subtitle,
    this.badgeText,
    this.badgeColor = const Color(0xFF10B981),
    this.icon = Icons.location_on,
    this.iconColor = const Color(0xFFEAB308),
    this.isCenter = false,
  });
}

class OsmMapWidget extends StatefulWidget {
  final MapController? mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final List<OsmMapMarkerData> markers;
  final LatLng? routeStart;
  final LatLng? routeEnd;
  final double height;
  final bool showControls;
  final bool showRecenterButton;
  final bool isInteractive;
  final VoidCallback? onExpand;
  final VoidCallback? onRecenter;
  final void Function(LatLng point)? onTap;

  const OsmMapWidget({
    super.key,
    this.mapController,
    required this.initialCenter,
    this.initialZoom = 14.0,
    required this.markers,
    this.routeStart,
    this.routeEnd,
    this.height = 240,
    this.showControls = true,
    this.showRecenterButton = true,
    this.isInteractive = true,
    this.onExpand,
    this.onRecenter,
    this.onTap,
  });

  @override
  State<OsmMapWidget> createState() => _OsmMapWidgetState();
}

class _OsmMapWidgetState extends State<OsmMapWidget> {
  late final MapController _internalMapController;
  MapController get _mapController => widget.mapController ?? _internalMapController;
  RouteResult? _activeRoute;
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    _internalMapController = MapController();
    if (widget.routeStart != null && widget.routeEnd != null) {
      _loadRoute();
    }
  }

  @override
  void didUpdateWidget(covariant OsmMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCenter.latitude != oldWidget.initialCenter.latitude ||
        widget.initialCenter.longitude != oldWidget.initialCenter.longitude) {
      try {
        _mapController.move(widget.initialCenter, widget.initialZoom);
      } catch (_) {}
    }
    if (widget.routeStart != oldWidget.routeStart ||
        widget.routeEnd != oldWidget.routeEnd) {
      if (widget.routeStart != null && widget.routeEnd != null) {
        _loadRoute();
      }
    }
  }

  Future<void> _loadRoute() async {
    if (widget.routeStart == null || widget.routeEnd == null) return;
    setState(() => _isLoadingRoute = true);

    final result = await OpenRouteService.getDirections(
      start: widget.routeStart!,
      end: widget.routeEnd!,
    );

    if (mounted) {
      setState(() {
        _activeRoute = result;
        _isLoadingRoute = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: widget.initialZoom,
              minZoom: 10.0,
              maxZoom: 18.0,
              interactionOptions: InteractionOptions(
                flags: widget.isInteractive
                    ? (InteractiveFlag.all & ~InteractiveFlag.rotate)
                    : InteractiveFlag.none,
              ),
              onTap: widget.onTap != null ? (tapPosition, point) => widget.onTap!(point) : null,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'org.foodflow.network',
                tileBuilder: (context, tileWidget, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.90, 0,    0,    0, 10,
                      0,    0.92, 0,    0, 10,
                      0,    0,    0.90, 0, 10,
                      0,    0,    0,    1, 0,
                    ]),
                    child: tileWidget,
                  );
                },
              ),
              if (_activeRoute != null && _activeRoute!.points.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _activeRoute!.points,
                      strokeWidth: 4.5,
                      color: const Color(0xFF2563EB),
                      borderColor: const Color(0xFF1D4ED8),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: widget.markers.map((m) => _buildMarker(m)).toList(),
              ),
            ],
          ),

          // Zoom Controls
          if (widget.showControls)
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapBtn(
                    icon: Icons.add,
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                          _mapController.camera.center, currentZoom + 1);
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildMapBtn(
                    icon: Icons.remove,
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                          _mapController.camera.center, currentZoom - 1);
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildMapBtn(
                    icon: Icons.my_location_rounded,
                    onTap: () {
                      _mapController.move(
                          widget.initialCenter, widget.initialZoom);
                      if (widget.onRecenter != null) {
                        widget.onRecenter!();
                      }
                    },
                  ),
                ],
              ),
            ),

          // Floating Real Location Redirect Button when showControls is false
          if (!widget.showControls && widget.showRecenterButton)
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: Colors.white,
                elevation: 3,
                shadowColor: Colors.black38,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    try {
                      _mapController.move(widget.initialCenter, widget.initialZoom);
                    } catch (_) {}
                    if (widget.onRecenter != null) {
                      widget.onRecenter!();
                    }
                  },
                  child: Tooltip(
                    message: 'Redirect to real location',
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        size: 19,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Floating Expand Map Button
          if (widget.onExpand != null)
            Positioned(
              left: 12,
              bottom: 12,
              child: Material(
                color: Colors.white,
                elevation: 3,
                shadowColor: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: widget.onExpand,
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
                        Icon(Icons.open_in_full_rounded, size: 14, color: Color(0xFF1E293B)),
                        SizedBox(width: 5),
                        Text(
                          'Expand Map',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Route HUD Info if active
          if (_activeRoute != null)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.navigation_rounded,
                        size: 13, color: Color(0xFFEAB308)),
                    const SizedBox(width: 6),
                    Text(
                      '${_activeRoute!.formattedDistance} · ${_activeRoute!.formattedDuration}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isLoadingRoute)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFEAB308),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Calculating ORS route...',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Marker _buildMarker(OsmMapMarkerData data) {
    if (data.isCenter) {
      return Marker(
        point: data.point,
        width: 160,
        height: 64,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFEAB308),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.star_rounded, size: 16, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Marker(
      point: data.point,
      width: 180,
      height: 48,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF10B981), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  if (data.subtitle != null)
                    Text(
                      data.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
            if (data.badgeText != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: data.badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.badgeText!,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: data.badgeColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: const Color(0xFF334155)),
        ),
      ),
    );
  }
}
