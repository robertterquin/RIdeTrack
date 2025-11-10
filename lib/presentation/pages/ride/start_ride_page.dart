import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bikeapp/core/constants/app_colors.dart';
import 'package:bikeapp/core/services/gps_service.dart';
import 'package:bikeapp/presentation/widgets/map/map_widget.dart';

/// Start Ride Page
/// Real-time GPS tracking with live map display
class StartRidePage extends StatefulWidget {
  const StartRidePage({super.key});

  @override
  State<StartRidePage> createState() => _StartRidePageState();
}

class _StartRidePageState extends State<StartRidePage> {
  final GpsService _gpsService = GpsService();
  final MapController _mapController = MapController();
  
  LatLng _currentPosition = const LatLng(14.5995, 120.9842); // Default: Manila
  bool _isTracking = false;
  bool _isLoading = true;
  bool _permissionGranted = false;
  
  // Ride stats
  double _distance = 0.0;
  int _duration = 0; // in seconds
  double _currentSpeed = 0.0;
  List<LatLng> _routePoints = [];
  
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    // Request location permission
    final hasPermission = await _gpsService.requestPermission();
    
    if (!hasPermission) {
      setState(() {
        _isLoading = false;
        _permissionGranted = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Location permission is required to track your ride')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() {
      _permissionGranted = true;
    });

    // Get current position
    try {
      final position = await _gpsService.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      
      // Center map on current location
      _mapController.move(_currentPosition, 16);
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startTracking() {
    if (!_permissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Location permission required'),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() {
      _isTracking = true;
      _routePoints.add(_currentPosition);
    });

    // Start listening to position updates
    _gpsService.getPositionStream().listen((Position position) {
      if (!_isTracking) return;

      final newPosition = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentPosition = newPosition;
        _currentSpeed = position.speed;
        _routePoints.add(newPosition);
        
        // Calculate distance if we have a last position
        if (_lastPosition != null) {
          final distanceInMeters = _gpsService.calculateDistance(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          _distance += distanceInMeters / 1000; // Convert to km
        }
        
        _lastPosition = position;
        _duration++;
      });

      // Update map center to follow user
      _mapController.move(newPosition, 16);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 12),
            Text('Ride tracking started!'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _pauseTracking() {
    setState(() {
      _isTracking = false;
    });
  }

  void _stopTracking() {
    setState(() {
      _isTracking = false;
    });

    // TODO: Save ride data to Firestore
    // Show ride summary
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ride Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distance: ${_distance.toStringAsFixed(2)} km'),
            Text('Duration: ${_formatDuration(_duration)}'),
            Text('Avg Speed: ${(_distance / (_duration / 3600)).toStringAsFixed(1)} km/h'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to rides page
            },
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Save ride to Firestore
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to rides page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: const Text('Save Ride'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryOrange,
                  ),
                )
              : MapWidget(
                  initialCenter: _currentPosition,
                  initialZoom: 16,
                  mapController: _mapController,
                  markers: [
                    Marker(
                      point: _currentPosition,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
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
                  ],
                  polylines: _routePoints.length > 1
                      ? [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4.0,
                            color: AppColors.primaryOrange,
                          ),
                        ]
                      : null,
                ),

          // Top Stats Card
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.straighten,
                    value: '${_distance.toStringAsFixed(2)} km',
                    label: 'Distance',
                  ),
                  Container(width: 1, height: 40, color: AppColors.lightGrey),
                  _buildStatItem(
                    icon: Icons.access_time,
                    value: _formatDuration(_duration),
                    label: 'Duration',
                  ),
                  Container(width: 1, height: 40, color: AppColors.lightGrey),
                  _buildStatItem(
                    icon: Icons.speed,
                    value: '${(_currentSpeed * 3.6).toStringAsFixed(1)} km/h',
                    label: 'Speed',
                  ),
                ],
              ),
            ),
          ),

          // Control Buttons
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: Column(
              children: [
                if (!_isTracking)
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _startTracking,
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text(
                        'Start Ride',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                if (_isTracking)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: _pauseTracking,
                            icon: const Icon(Icons.pause, size: 28),
                            label: const Text(
                              'Pause',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: _stopTracking,
                            icon: const Icon(Icons.stop, size: 28),
                            label: const Text(
                              'Stop',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Back Button
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryOrange, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
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
