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
        final data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && data['trips'] != null && data['trips'].isNotEmpty) {
          final trip = data['trips'][0];
          
          // Extraire la géométrie de la route
          final geometry = trip['geometry'];
          final List<LatLng> routePoints = [];
          
          if (geometry != null && geometry['coordinates'] != null) {
            for (var coord in geometry['coordinates']) {
              routePoints.add(LatLng(coord[1], coord[0])); // [lng, lat] -> LatLng(lat, lng)
            }
          }
          
          // Extraire l'ordre optimisé des waypoints
          final List<int> waypointOrder = [];
          if (trip['waypoints'] != null) {
            for (var wp in trip['waypoints']) {
              waypointOrder.add(wp['waypoint_index'] as int);
            }
          }
          
          // Extraire les étapes (legs)
          final List<RouteLeg> legs = [];
          if (trip['legs'] != null) {
            for (var leg in trip['legs']) {
              legs.add(RouteLeg(
                distance: (leg['distance'] as num).toDouble(),
                duration: (leg['duration'] as num).toDouble(),
                steps: _extractSteps(leg['steps']),
              ));
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
        final data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          final geometry = route['geometry'];
          final List<LatLng> routePoints = [];
          
          if (geometry != null && geometry['coordinates'] != null) {
            for (var coord in geometry['coordinates']) {
              routePoints.add(LatLng(coord[1], coord[0]));
            }
          }
          
          final List<RouteLeg> legs = [];
          if (route['legs'] != null) {
            for (var leg in route['legs']) {
              legs.add(RouteLeg(
                distance: (leg['distance'] as num).toDouble(),
                duration: (leg['duration'] as num).toDouble(),
                steps: _extractSteps(leg['steps']),
              ));
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
    
    return stepsData.map((step) {
      return RouteStep(
        distance: (step['distance'] as num?)?.toDouble() ?? 0,
        duration: (step['duration'] as num?)?.toDouble() ?? 0,
        instruction: step['maneuver']?['instruction'] ?? '',
        name: step['name'] ?? '',
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
