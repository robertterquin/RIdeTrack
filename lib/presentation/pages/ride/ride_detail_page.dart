import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import '../../../data/models/ride.dart';
import '../../../core/constants/app_colors.dart';

class RideDetailPage extends StatelessWidget {
  final Ride ride;

  const RideDetailPage({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          ride.name,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map showing the route
            _buildMapSection(),
            
            // Ride stats
            _buildStatsSection(),
            
            // Ride details
            _buildDetailsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    // Use actual route if available, otherwise use planned route
    final routeToShow = ride.actualRoute.isNotEmpty 
        ? ride.actualRoute 
        : (ride.plannedRoute ?? []);

    return Container(
      height: 320,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: routeToShow.isEmpty
            ? Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No route data available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            : FlutterMap(
                options: MapOptions(
                  initialCenter: routeToShow.first,
                  initialZoom: 14,
                  minZoom: 10,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                  onMapReady: () {
                    // Map is ready
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.bikeapp',
                  ),
                  // Show both planned route (if exists) and actual route
                  if (ride.plannedRoute != null && ride.plannedRoute!.isNotEmpty && ride.actualRoute.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: ride.plannedRoute!,
                          strokeWidth: 3,
                          color: Colors.blue.withOpacity(0.5),
                          borderStrokeWidth: 1,
                          borderColor: Colors.white,
                        ),
                      ],
                    ),
                  // Actual route or planned route (primary)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routeToShow,
                        strokeWidth: 4,
                        color: AppColors.primaryPurple,
                        borderStrokeWidth: 2,
                        borderColor: Colors.white,
                      ),
                    ],
                  ),
                  // Start marker
                  if (routeToShow.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: routeToShow.first,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        // End marker
                        Marker(
                          point: routeToShow.last,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.stop,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryPurple.withOpacity(0.1),
            AppColors.primaryPurple.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.1),
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
            label: 'Distance',
            value: _formatDistance(ride.distance),
          ),
          Container(
            width: 1,
            height: 60,
            color: AppColors.primaryPurple.withOpacity(0.2),
          ),
          _buildStatItem(
            icon: Icons.access_time,
            label: 'Duration',
            value: _formatDuration(ride.duration),
          ),
          Container(
            width: 1,
            height: 60,
            color: AppColors.primaryPurple.withOpacity(0.2),
          ),
          _buildStatItem(
            icon: Icons.speed,
            label: 'Avg Speed',
            value: '${ride.averageSpeed.toStringAsFixed(1)} km/h',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryPurple, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ride Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  icon: Icons.directions_bike,
                  label: 'Type',
                  value: ride.type,
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value: DateFormat('EEEE, MMMM d, yyyy').format(ride.startTime),
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  icon: Icons.schedule,
                  label: 'Start Time',
                  value: DateFormat('h:mm a').format(ride.startTime),
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  icon: Icons.flag,
                  label: 'End Time',
                  value: DateFormat('h:mm a').format(ride.endTime),
                ),
                if (ride.startLocation != null) ...[
                  const Divider(height: 24),
                  _buildDetailRow(
                    icon: Icons.location_on,
                    label: 'Start Location',
                    value: '${ride.startLocation!.latitude.toStringAsFixed(5)}, ${ride.startLocation!.longitude.toStringAsFixed(5)}',
                  ),
                ],
                if (ride.endLocation != null) ...[
                  const Divider(height: 24),
                  _buildDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'End Location',
                    value: '${ride.endLocation!.latitude.toStringAsFixed(5)}, ${ride.endLocation!.longitude.toStringAsFixed(5)}',
                  ),
                ],
              ],
            ),
          ),
          if (ride.notes != null && ride.notes!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Notes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                ride.notes!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ],
          // Route information
          const SizedBox(height: 20),
          const Text(
            'Route Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  icon: Icons.route,
                  label: 'Total Points',
                  value: '${ride.actualRoute.length} GPS points',
                ),
                const Divider(height: 24),
                if (ride.plannedRoute != null && ride.plannedRoute!.isNotEmpty && ride.actualRoute.isNotEmpty)
                  _buildDetailRow(
                    icon: Icons.compare_arrows,
                    label: 'Route Type',
                    value: 'Planned + Tracked',
                  )
                else if (ride.actualRoute.isNotEmpty)
                  _buildDetailRow(
                    icon: Icons.gps_fixed,
                    label: 'Route Type',
                    value: 'GPS Tracked',
                  )
                else if (ride.plannedRoute != null && ride.plannedRoute!.isNotEmpty)
                  _buildDetailRow(
                    icon: Icons.map,
                    label: 'Route Type',
                    value: 'Planned Only',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.primaryPurple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
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
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes} min';
    }
  }
}
