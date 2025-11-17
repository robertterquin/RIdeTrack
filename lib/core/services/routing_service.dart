import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service for route calculation and geocoding
class RoutingService {
  /// Get route between two points using OSRM bike profile
  /// Uses bicycle routing which avoids expressways and highways
  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    try {
      // Using OSRM free routing service with bike profile
      // This automatically avoids expressways, highways, and motorways
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/bike/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          
          return coordinates.map((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();
        }
      }
      
      // Fallback: direct line between points
      return [start, end];
    } catch (e) {
      print('Error getting route: $e');
      // Fallback: direct line between points
      return [start, end];
    }
  }

  /// Get route distance in meters using bike-friendly routes
  Future<double> getRouteDistance(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/bike/${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          return (data['routes'][0]['distance'] as num).toDouble();
        }
      }
      
      // Fallback: straight-line distance
      const distance = Distance();
      return distance.as(LengthUnit.Meter, start, end);
    } catch (e) {
      print('Error getting route distance: $e');
      // Fallback: straight-line distance
      const distance = Distance();
      return distance.as(LengthUnit.Meter, start, end);
    }
  }

  /// Get estimated duration in seconds for bike-friendly routes
  Future<int> getRouteDuration(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/bike/${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          return (data['routes'][0]['duration'] as num).toInt();
        }
      }
      
      // Fallback: estimate based on distance (assume 20 km/h cycling speed)
      const distance = Distance();
      final meters = distance.as(LengthUnit.Meter, start, end);
      return (meters / (20000 / 3600)).round(); // 20 km/h in m/s
    } catch (e) {
      print('Error getting route duration: $e');
      // Fallback: estimate based on distance
      const distance = Distance();
      final meters = distance.as(LengthUnit.Meter, start, end);
      return (meters / (20000 / 3600)).round();
    }
  }
}
