import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bikeapp/core/constants/app_colors.dart';
import 'package:bikeapp/presentation/widgets/map/map_widget.dart';
import 'package:bikeapp/core/services/routing_service.dart';
import 'package:bikeapp/core/services/gps_service.dart';
import 'package:bikeapp/data/repositories/ride_repository.dart';
import 'package:bikeapp/data/models/ride.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bikeapp/core/utils/calorie_calculator.dart';

/// Unified Ride Page
/// Plan routes, start rides, track GPS with optional route following
class UnifiedRidePage extends StatefulWidget {
  const UnifiedRidePage({super.key});

  @override
  State<UnifiedRidePage> createState() => _UnifiedRidePageState();
}

class _UnifiedRidePageState extends State<UnifiedRidePage> {
  final _endController = TextEditingController();
  final _routingService = RoutingService();
  final _gpsService = GpsService();
  final _rideRepository = RideRepository();
  final _mapController = MapController();

  // Route planning
  LatLng? _startPoint;
  LatLng? _endPoint;
  List<LatLng> _plannedRoute = [];
  double? _plannedDistance;
  int? _plannedDuration;
  bool _isCalculatingRoute = false;
  List<Location> _endSuggestions = [];
  bool _showEndSuggestions = false;

  // Ride tracking
  bool _isRiding = false;
  bool _isPaused = false;
  List<LatLng> _actualRoute = [];
  LatLng? _currentLocation;
  double _totalDistance = 0.0;
  int _elapsedSeconds = 0;
  double _currentSpeed = 0.0;
  DateTime? _rideStartTime;
  Timer? _timer;
  Timer? _locationRefreshTimer;
  StreamSubscription<Position>? _positionStream;
  double _currentAccuracy = 0.0;
  static const double _accuracyThreshold = 50.0; // Reject positions worse than 50m accuracy

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _endController.dispose();
    _timer?.cancel();
    _locationRefreshTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final hasPermission = await _gpsService.requestPermission();
      if (!hasPermission) {
        print('❌ Location permission denied');
        return;
      }

      // Try to get last known position first for quick initial display
      final lastPosition = await _gpsService.getLastKnownPosition();
      if (lastPosition != null && mounted) {
        setState(() {
          _currentLocation = LatLng(lastPosition.latitude, lastPosition.longitude);
          _startPoint = _currentLocation;
          _currentAccuracy = lastPosition.accuracy;
        });
        _mapController.move(_currentLocation!, 15.0);
        print('📍 Using last known position (accuracy: ${lastPosition.accuracy.toStringAsFixed(1)}m)');
      }

      // Then get fresh high-accuracy position
      final position = await _gpsService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _startPoint = _currentLocation;
          _currentAccuracy = position.accuracy;
        });
        _mapController.move(_currentLocation!, 15.0);
        print('✅ Got fresh position (accuracy: ${position.accuracy.toStringAsFixed(1)}m)');
      }

      // Start periodic refresh when not riding
      _startLocationRefresh();
    } catch (e) {
      print('❌ Error getting current location: $e');
    }
  }

  /// Periodically refresh location when not riding
  void _startLocationRefresh() {
    _locationRefreshTimer?.cancel();
    if (!_isRiding) {
      _locationRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (!_isRiding && mounted) {
          try {
            final position = await _gpsService.getCurrentPosition();
            if (mounted && position.accuracy < _accuracyThreshold) {
              setState(() {
                _currentLocation = LatLng(position.latitude, position.longitude);
                _startPoint = _currentLocation;
                _currentAccuracy = position.accuracy;
              });
              print('🔄 Location refreshed (accuracy: ${position.accuracy.toStringAsFixed(1)}m)');
            }
          } catch (e) {
            print('⚠️ Location refresh failed: $e');
          }
        }
      });
    }
  }

  /// Stop location refresh timer
  void _stopLocationRefresh() {
    _locationRefreshTimer?.cancel();
    _locationRefreshTimer = null;
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _endSuggestions = [];
        _showEndSuggestions = false;
      });
      return;
    }

    try {
      final locations = await locationFromAddress(query);
      
      if (mounted) {
        setState(() {
          _endSuggestions = locations;
          _showEndSuggestions = locations.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error searching location: $e');
      if (mounted) {
        setState(() {
          _showEndSuggestions = false;
        });
      }
    }
  }

  Future<void> _selectDestination(Location location) async {
    final latLng = LatLng(location.latitude, location.longitude);
    
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final address = '${place.street ?? ''}, ${place.locality ?? ''}';
        
        setState(() {
          _endPoint = latLng;
          _endController.text = address;
          _showEndSuggestions = false;
        });

        await _calculateRoute();
      }
    } catch (e) {
      print('Error getting placemark: $e');
    }
  }

  Future<void> _onMapTap(LatLng point) async {
    if (_isRiding) return; // Don't allow changing route while riding

    setState(() {
      _endPoint = point;
    });
    
    try {
      final placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        _endController.text = '${place.street ?? place.locality ?? 'Selected location'}';
      } else {
        _endController.text = 'Lat: ${point.latitude.toStringAsFixed(4)}, Lng: ${point.longitude.toStringAsFixed(4)}';
      }
    } catch (e) {
      _endController.text = 'Lat: ${point.latitude.toStringAsFixed(4)}, Lng: ${point.longitude.toStringAsFixed(4)}';
    }
    
    await _calculateRoute();
  }

  Future<void> _calculateRoute() async {
    if (_startPoint == null || _endPoint == null) return;

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      final route = await _routingService.getRoute(_startPoint!, _endPoint!);
      final distance = await _routingService.getRouteDistance(_startPoint!, _endPoint!);
      final duration = await _routingService.getRouteDuration(_startPoint!, _endPoint!);

      if (mounted) {
        setState(() {
          _plannedRoute = route;
          _plannedDistance = distance;
          _plannedDuration = duration;
          _isCalculatingRoute = false;
        });

        if (_plannedRoute.length >= 2) {
          final bounds = LatLngBounds.fromPoints(_plannedRoute);
          _mapController.fitCamera(CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(80),
          ));
        }
      }
    } catch (e) {
      print('Error calculating route: $e');
      if (mounted) {
        setState(() {
          _isCalculatingRoute = false;
        });
      }
    }
  }

  void _startRide() {
    // Stop location refresh timer (will use GPS stream instead)
    _stopLocationRefresh();
    
    setState(() {
      _isRiding = true;
      _isPaused = false;
      _actualRoute = [];
      _totalDistance = 0.0;
      _elapsedSeconds = 0;
      _rideStartTime = DateTime.now();
      if (_currentLocation != null) {
        _actualRoute.add(_currentLocation!);
      }
    });

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });

    // Start GPS tracking with accuracy filtering
    _positionStream = _gpsService.getPositionStream().listen((position) {
      if (!_isPaused && mounted) {
        // Filter out inaccurate positions
        if (position.accuracy > _accuracyThreshold) {
          print('⚠️ Rejecting inaccurate position (accuracy: ${position.accuracy.toStringAsFixed(1)}m)');
          return;
        }

        final newLocation = LatLng(position.latitude, position.longitude);
        
        // Reject positions that are too far from last point (likely GPS jump)
        if (_actualRoute.isNotEmpty) {
          final lastPoint = _actualRoute.last;
          final distance = _gpsService.calculateDistance(
            lastPoint.latitude,
            lastPoint.longitude,
            newLocation.latitude,
            newLocation.longitude,
          );
          
          // Reject if distance is unrealistic (more than 100m in update interval)
          // At 50 km/h, you travel ~14m per second, so 100m is very generous for 5-10s updates
          if (distance > 100) {
            print('⚠️ Rejecting GPS jump: ${distance.toStringAsFixed(0)}m from last point');
            return;
          }
        }
        
        setState(() {
          // Calculate distance from last point
          if (_actualRoute.isNotEmpty) {
            final lastPoint = _actualRoute.last;
            final distance = _gpsService.calculateDistance(
              lastPoint.latitude,
              lastPoint.longitude,
              newLocation.latitude,
              newLocation.longitude,
            );
            _totalDistance += distance;
          }
          
          _currentLocation = newLocation;
          _actualRoute.add(newLocation);
          _currentSpeed = position.speed * 3.6; // m/s to km/h
          _currentAccuracy = position.accuracy;
        });

        print('✅ Position updated (accuracy: ${position.accuracy.toStringAsFixed(1)}m, speed: ${_currentSpeed.toStringAsFixed(1)} km/h)');

        // Keep map centered on current location
        _mapController.move(newLocation, _mapController.camera.zoom);
      }
    });
  }

  void _pauseRide() {
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeRide() {
    setState(() {
      _isPaused = false;
    });
  }

  void _stopRide() {
    _timer?.cancel();
    _positionStream?.cancel();
    
    // Restart location refresh for planning mode
    _startLocationRefresh();

    _showRideSummary();
  }

  void _showRideSummary() async {
    final TextEditingController rideNameController = TextEditingController();
    String selectedType = 'Recreation';
    
    // Calculate estimated calories
    double? estimatedCalories;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final weight = (userDoc.data()?['weight'] as num?)?.toDouble();
          final avgSpeed = _elapsedSeconds > 0
              ? (_totalDistance / 1000) / (_elapsedSeconds / 3600)
              : 0.0;
          
          if (weight != null && weight > 0) {
            estimatedCalories = CalorieCalculator.calculateCaloriesFromSeconds(
              weightKg: weight,
              avgSpeedKmh: avgSpeed,
              durationSeconds: _elapsedSeconds,
            );
          }
        }
      } catch (e) {
        print('Error calculating calories for summary: $e');
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ride Complete!'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow(Icons.straighten, 'Distance', _formatDistance(_totalDistance)),
                const SizedBox(height: 12),
                _buildSummaryRow(Icons.access_time, 'Duration', _formatDuration(_elapsedSeconds)),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  Icons.speed,
                  'Avg Speed',
                  _elapsedSeconds > 0
                      ? '${((_totalDistance / 1000) / (_elapsedSeconds / 3600)).toStringAsFixed(1)} km/h'
                      : '0 km/h',
                ),
                if (estimatedCalories != null) ...[
                  const SizedBox(height: 12),
                  _buildSummaryRow(Icons.local_fire_department, 'Calories', '${estimatedCalories.toStringAsFixed(0)} kcal'),
                ],
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                TextField(
                  controller: rideNameController,
                  decoration: InputDecoration(
                    labelText: 'Ride Name',
                    hintText: 'e.g., Morning Commute',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Ride Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Recreation', child: Text('Recreation')),
                    DropdownMenuItem(value: 'Commute', child: Text('Commute')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                rideNameController.dispose();
                Navigator.of(context).pop();
                setState(() {
                  _isRiding = false;
                  _isPaused = false;
                  _actualRoute = [];
                  _totalDistance = 0.0;
                  _elapsedSeconds = 0;
                  _currentSpeed = 0.0;
                  _plannedRoute = [];
                  _endPoint = null;
                  _endController.clear();
                });
              },
              child: const Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveRide(
                  rideName: rideNameController.text.trim(),
                  rideType: selectedType,
                );
                rideNameController.dispose();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
              ),
              child: const Text('Save Ride', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRide({required String rideName, required String rideType}) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      );

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('No user logged in');
      }

      // Generate ride name if not provided
      final finalRideName = rideName.isEmpty
          ? _generateRideName()
          : rideName;

      // Calculate average speed
      final avgSpeed = _elapsedSeconds > 0
          ? (_totalDistance / 1000) / (_elapsedSeconds / 3600)
          : 0.0;

      // Fetch user weight for calorie calculation
      double? calories;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final weight = (userDoc.data()?['weight'] as num?)?.toDouble();
          if (weight != null && weight > 0) {
            // Calculate calories using MET formula
            calories = CalorieCalculator.calculateCaloriesFromSeconds(
              weightKg: weight,
              avgSpeedKmh: avgSpeed,
              durationSeconds: _elapsedSeconds,
            );
          }
        }
      } catch (e) {
        print('Error calculating calories: $e');
        // Continue without calories if there's an error
      }

      // Create ride object
      final ride = Ride(
        id: '', // Will be set by Firestore
        userId: userId,
        name: finalRideName,
        type: rideType,
        distance: _totalDistance,
        duration: _elapsedSeconds,
        averageSpeed: avgSpeed,
        startTime: _rideStartTime!,
        endTime: DateTime.now(),
        actualRoute: _actualRoute,
        plannedRoute: _plannedRoute.isNotEmpty ? _plannedRoute : null,
        startLocation: _actualRoute.isNotEmpty ? _actualRoute.first : null,
        endLocation: _actualRoute.isNotEmpty ? _actualRoute.last : null,
        calories: calories,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await _rideRepository.saveRide(ride);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // Close summary dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Ride "$finalRideName" saved successfully!')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );

        // Go back to dashboard
        Navigator.of(context).pop();
      }

      // Reset state
      setState(() {
        _isRiding = false;
        _isPaused = false;
        _actualRoute = [];
        _totalDistance = 0.0;
        _elapsedSeconds = 0;
        _currentSpeed = 0.0;
        _plannedRoute = [];
        _endPoint = null;
        _endController.clear();
      });
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error saving ride: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _generateRideName() {
    final now = DateTime.now();
    final hour = now.hour;
    
    String timeOfDay;
    if (hour < 12) {
      timeOfDay = 'Morning';
    } else if (hour < 17) {
      timeOfDay = 'Afternoon';
    } else {
      timeOfDay = 'Evening';
    }
    
    return '$timeOfDay Ride';
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryOrange, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !_isRiding,
        leading: _isRiding ? null : IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isRiding ? 'Riding' : 'Plan & Ride',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Map
          MapWidget(
            initialCenter: _currentLocation ?? const LatLng(14.5995, 120.9842),
            initialZoom: 15.0,
            mapController: _mapController,
            onTap: _isRiding ? null : _onMapTap,
            markers: [
              // Current location marker
              if (_currentLocation != null)
                Marker(
                  point: _currentLocation!,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.navigation,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              // Destination marker
              if (_endPoint != null && !_isRiding)
                Marker(
                  point: _endPoint!,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
            polylines: [
              // Planned route (light gray when riding, violet when planning)
              if (_plannedRoute.isNotEmpty)
                Polyline(
                  points: _plannedRoute,
                  strokeWidth: 4.0,
                  color: _isRiding
                      ? Colors.grey.withOpacity(0.5)
                      : AppColors.primaryPurple,
                ),
              // Actual route (violet, shown while riding)
              if (_actualRoute.length >= 2)
                Polyline(
                  points: _actualRoute,
                  strokeWidth: 5.0,
                  color: AppColors.primaryPurple,
                ),
            ],
          ),

          // Planning Panel (only visible when not riding)
          if (!_isRiding)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Instructions
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.touch_app, color: AppColors.primaryOrange, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _endPoint == null
                                      ? 'Tap on map or search to set destination (optional)'
                                      : 'Route planned! Tap Start Ride to begin',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 12),

                        // Destination Search
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _endController,
                                decoration: InputDecoration(
                                  hintText: 'Destination (optional)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.backgroundGrey,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  suffixIcon: _endController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 20),
                                          onPressed: () {
                                            _endController.clear();
                                            setState(() {
                                              _endPoint = null;
                                              _plannedRoute = [];
                                              _plannedDistance = null;
                                              _plannedDuration = null;
                                              _showEndSuggestions = false;
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: _searchLocation,
                                onTap: () {
                                  if (_endSuggestions.isNotEmpty) {
                                    setState(() {
                                      _showEndSuggestions = true;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        // Route Info
                        if (_plannedDistance != null && _plannedDuration != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      const Icon(Icons.straighten, 
                                        color: AppColors.primaryPurple, size: 20),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDistance(_plannedDistance!),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Text(
                                        'Distance',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      const Icon(Icons.access_time, 
                                        color: AppColors.primaryPurple, size: 20),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDuration(_plannedDuration!),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Text(
                                        'Est. Time',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Suggestions Dropdown
          if (_showEndSuggestions && _endSuggestions.isNotEmpty && !_isRiding)
            Positioned(
              top: _plannedDistance != null ? 240 : 170,
              left: 16,
              right: 16,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _endSuggestions.length > 5 ? 5 : _endSuggestions.length,
                  itemBuilder: (context, index) {
                    final location = _endSuggestions[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.red),
                      title: Text('${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}'),
                      onTap: () => _selectDestination(location),
                    );
                  },
                ),
              ),
            ),

          // Ride Stats Panel (visible when riding)
          if (_isRiding)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          _formatDistance(_totalDistance),
                          'Distance',
                          Icons.straighten,
                        ),
                        _buildStatCard(
                          _formatDuration(_elapsedSeconds),
                          'Duration',
                          Icons.access_time,
                        ),
                        _buildStatCard(
                          '${_currentSpeed.toStringAsFixed(1)} km/h',
                          'Speed',
                          Icons.speed,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Calculating indicator
          if (_isCalculatingRoute)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primaryOrange),
                      SizedBox(width: 16),
                      Text('Calculating route...'),
                    ],
                  ),
                ),
              ),
            ),

          // Action Buttons
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _isRiding
                ? Row(
                    children: [
                      if (!_isPaused)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pauseRide,
                            icon: const Icon(Icons.pause, color: Colors.white),
                            label: const Text('Pause', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      if (_isPaused)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _resumeRide,
                            icon: const Icon(Icons.play_arrow, color: Colors.white),
                            label: const Text('Resume', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _stopRide,
                          icon: const Icon(Icons.stop, color: Colors.white),
                          label: const Text('Stop', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ElevatedButton.icon(
                    onPressed: _startRide,
                    icon: const Icon(Icons.play_circle_filled, color: Colors.white),
                    label: const Text(
                      'Start Ride',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryOrange, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
