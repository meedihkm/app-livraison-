import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service pour calculer des itinéraires optimisés avec OSRM (gratuit)
class RouteService {
  // OSRM Demo Server (gratuit, limité à usage raisonnable)
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';
  
  /// Calcule l'itinéraire optimisé pour visiter plusieurs points
  /// Utilise l'algorithme TSP (Traveling Salesman Problem) d'OSRM
  Future<RouteResult?> calculateOptimizedRoute({
    required LatLng start,
    required List<LatLng> destinations,
  }) async {
    try {
      // Construire la liste de coordonnées (start + destinations)
      final coordinates = [start, ...destinations];
      final coordsString = coordinates
          .map((c) => '${c.longitude},${c.latitude}')
          .join(';');
      
      // Appel à l'API OSRM Trip (optimisation TSP)
      final url = Uri.parse(
        '$_osrmBaseUrl/trip/v1/driving/$coordsString?source=first&destination=last&roundtrip=false&geometries=geojson&overview=full&steps=true'
      );
      
      final response = await http.get(url).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['code'] == 'Ok' && data['trips'] is List && (data['trips'] as List).isNotEmpty) {
          final trips = data['trips'] as List<dynamic>;
          final trip = trips[0] as Map<String, dynamic>;
          
          // Extraire la géométrie de la route
          final geometry = trip['geometry'] as Map<String, dynamic>?;
          final List<LatLng> routePoints = [];
          
          if (geometry != null && geometry['coordinates'] is List) {
            final coordinatesList = geometry['coordinates'] as List<dynamic>;
            for (var coord in coordinatesList) {
              if (coord is List && coord.length >= 2) {
                routePoints.add(LatLng(
                  (coord[1] as num).toDouble(),
                  (coord[0] as num).toDouble(),
                ));
              }
            }
          }
          
          // Extraire l'ordre optimisé des waypoints
          final List<int> waypointOrder = [];
          if (trip['waypoints'] is List) {
            final waypointsList = trip['waypoints'] as List<dynamic>;
            for (var wp in waypointsList) {
              if (wp is Map<String, dynamic>) {
                waypointOrder.add(wp['waypoint_index'] as int);
              }
            }
          }
          
          // Extraire les étapes (legs)
          final List<RouteLeg> legs = [];
          if (trip['legs'] is List) {
            final legsList = trip['legs'] as List<dynamic>;
            for (var leg in legsList) {
              if (leg is Map<String, dynamic>) {
                legs.add(RouteLeg(
                  distance: (leg['distance'] as num).toDouble(),
                  duration: (leg['duration'] as num).toDouble(),
                  steps: _extractSteps(leg['steps'] as List<dynamic>?),
                ));
              }
            }
          }
          
          return RouteResult(
            routePoints: routePoints,
            totalDistance: (trip['distance'] as num).toDouble(),
            totalDuration: (trip['duration'] as num).toDouble(),
            waypointOrder: waypointOrder,
            legs: legs,
          );
        }
      }
      
      return null;
    } catch (e) {
      print('Error calculating route: $e');
      return null;
    }
  }
  
  /// Calcule un itinéraire simple entre deux points
  Future<RouteResult?> calculateSimpleRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    try {
      final coordsString = '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
      
      final url = Uri.parse(
        '$_osrmBaseUrl/route/v1/driving/$coordsString?geometries=geojson&overview=full&steps=true'
      );
      
      final response = await http.get(url).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['code'] == 'Ok' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
          final routes = data['routes'] as List<dynamic>;
          final route = routes[0] as Map<String, dynamic>;
          
          final geometry = route['geometry'] as Map<String, dynamic>?;
          final List<LatLng> routePoints = [];
          
          if (geometry != null && geometry['coordinates'] is List) {
            final coordinatesList = geometry['coordinates'] as List<dynamic>;
            for (var coord in coordinatesList) {
              if (coord is List && coord.length >= 2) {
                routePoints.add(LatLng(
                  (coord[1] as num).toDouble(),
                  (coord[0] as num).toDouble(),
                ));
              }
            }
          }
          
          final List<RouteLeg> legs = [];
          if (route['legs'] is List) {
            final legsList = route['legs'] as List<dynamic>;
            for (var leg in legsList) {
              if (leg is Map<String, dynamic>) {
                legs.add(RouteLeg(
                  distance: (leg['distance'] as num).toDouble(),
                  duration: (leg['duration'] as num).toDouble(),
                  steps: _extractSteps(leg['steps'] as List<dynamic>?),
                ));
              }
            }
          }
          
          return RouteResult(
            routePoints: routePoints,
            totalDistance: (route['distance'] as num).toDouble(),
            totalDuration: (route['duration'] as num).toDouble(),
            waypointOrder: [0, 1],
            legs: legs,
          );
        }
      }
      
      return null;
    } catch (e) {
      print('Error calculating simple route: $e');
      return null;
    }
  }
  
  List<RouteStep> _extractSteps(List<dynamic>? stepsData) {
    if (stepsData == null) return [];
    
    return stepsData.whereType<Map<String, dynamic>>().map((step) {
      final maneuver = step['maneuver'] as Map<String, dynamic>?;
      return RouteStep(
        distance: (step['distance'] as num?)?.toDouble() ?? 0,
        duration: (step['duration'] as num?)?.toDouble() ?? 0,
        instruction: (maneuver?['instruction'] as String?) ?? '',
        name: (step['name'] as String?) ?? '',
      );
    }).toList();
  }
}

/// Résultat d'un calcul d'itinéraire
class RouteResult {
  final List<LatLng> routePoints;
  final double totalDistance; // en mètres
  final double totalDuration; // en secondes
  final List<int> waypointOrder; // Ordre optimisé des points
  final List<RouteLeg> legs;
  
  RouteResult({
    required this.routePoints,
    required this.totalDistance,
    required this.totalDuration,
    required this.waypointOrder,
    required this.legs,
  });
  
  String get formattedDistance {
    if (totalDistance < 1000) {
      return '${totalDistance.toStringAsFixed(0)} m';
    }
    return '${(totalDistance / 1000).toStringAsFixed(1)} km';
  }
  
  String get formattedDuration {
    final minutes = (totalDuration / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}min';
  }
}

/// Segment d'itinéraire entre deux points
class RouteLeg {
  final double distance;
  final double duration;
  final List<RouteStep> steps;
  
  RouteLeg({
    required this.distance,
    required this.duration,
    required this.steps,
  });
}

/// Étape de navigation
class RouteStep {
  final double distance;
  final double duration;
  final String instruction;
  final String name;
  
  RouteStep({
    required this.distance,
    required this.duration,
    required this.instruction,
    required this.name,
  });
}
