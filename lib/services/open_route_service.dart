import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.steps = const [],
  });

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  String get formattedDuration {
    final mins = (durationSeconds / 60).round();
    if (mins >= 60) {
      final hours = mins ~/ 60;
      final remMins = mins % 60;
      return '${hours}h ${remMins}m';
    }
    return '$mins mins';
  }
}

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class OpenRouteService {
  static const String apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImY1MjZkMzQ1YjE3ZjRjNGU5MDBmMzhhYjcwOTY5MzNmIiwiaCI6Im11cm11cjY0In0=';
  static const String baseUrl = 'https://api.openrouteservice.org/v2/directions';

  /// Fetch route from OpenRouteService
  static Future<RouteResult> getDirections({
    required LatLng start,
    required LatLng end,
    String profile = 'driving-car', // 'driving-car', 'cycling-regular', 'foot-walking'
  }) async {
    final uri = Uri.parse(
      '$baseUrl/$profile?api_key=$apiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final feature = features[0];
          final geometry = feature['geometry'];
          final coordinates = geometry['coordinates'] as List?;

          final points = <LatLng>[];
          if (coordinates != null) {
            for (final coord in coordinates) {
              final lng = (coord[0] as num).toDouble();
              final lat = (coord[1] as num).toDouble();
              points.add(LatLng(lat, lng));
            }
          }

          final properties = feature['properties'] ?? {};
          final summary = properties['summary'] ?? {};
          final distance = (summary['distance'] as num?)?.toDouble() ?? 0.0;
          final duration = (summary['duration'] as num?)?.toDouble() ?? 0.0;

          final stepsList = <RouteStep>[];
          final segments = properties['segments'] as List?;
          if (segments != null && segments.isNotEmpty) {
            final rawSteps = segments[0]['steps'] as List?;
            if (rawSteps != null) {
              for (final s in rawSteps) {
                stepsList.add(RouteStep(
                  instruction: s['instruction']?.toString() ?? '',
                  distanceMeters: (s['distance'] as num?)?.toDouble() ?? 0.0,
                  durationSeconds: (s['duration'] as num?)?.toDouble() ?? 0.0,
                ));
              }
            }
          }

          return RouteResult(
            points: points,
            distanceMeters: distance,
            durationSeconds: duration,
            steps: stepsList,
          );
        }
      }
    } catch (e) {
      debugPrint('OpenRouteService routing error: $e');
    }

    // Fallback: direct line between coordinates
    return RouteResult(
      points: [start, end],
      distanceMeters: const Distance().as(LengthUnit.Meter, start, end),
      durationSeconds: (const Distance().as(LengthUnit.Meter, start, end) / 8.33), // ~30 km/h
      steps: const [
        RouteStep(
          instruction: 'Proceed to destination along designated relief corridor',
          distanceMeters: 0,
          durationSeconds: 0,
        ),
      ],
    );
  }
}
