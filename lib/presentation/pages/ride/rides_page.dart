import 'package:flutter/material.dart';
import 'package:bikeapp/core/constants/app_colors.dart';
import 'package:bikeapp/data/repositories/ride_repository.dart';
import 'package:bikeapp/data/models/ride.dart';
import 'package:intl/intl.dart';
import 'ride_detail_page.dart';

/// Rides Page
/// Shows ride history, filters, and allows starting new rides
class RidesPage extends StatefulWidget {
  const RidesPage({super.key});

  @override
  State<RidesPage> createState() => _RidesPageState();
}

class _RidesPageState extends State<RidesPage> {
  String _selectedFilter = 'All'; // TODO: Implement actual filtering logic
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final RideRepository _rideRepository = RideRepository();
  List<Ride> _rides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRides() async {
    print('🔄 Rides page: Loading rides...');
    setState(() {
      _isLoading = true;
    });

    try {
      final rides = await _rideRepository.getRides();
      print('📊 Rides page received ${rides.length} rides');
      if (mounted) {
        setState(() {
          _rides = rides;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Rides page error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            floating: true,
            pinned: true,
            automaticallyImplyLeading: false,
            toolbarHeight: 72,
            flexibleSpace: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search rides...',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.6),
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.filter_list,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                      onSelected: (value) {
                        setState(() {
                          _selectedFilter = value;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.filter_list, color: Colors.white),
                                const SizedBox(width: 12),
                                Text('Filtering by: $value'),
                              ],
                            ),
                            backgroundColor: AppColors.primaryPurple,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.all(16),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'All', child: Text('All Rides')),
                        const PopupMenuItem(value: 'This Week', child: Text('This Week')),
                        const PopupMenuItem(value: 'This Month', child: Text('This Month')),
                        const PopupMenuItem(value: 'This Year', child: Text('This Year')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
            sliver: _buildRidesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRidesList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      );
    }

    // Filter rides based on search query
    final filteredRides = _rides.where((ride) {
      if (_searchQuery.isEmpty) return true;
      return ride.name.toLowerCase().contains(_searchQuery) ||
             ride.type.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredRides.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_bike_outlined,
                size: 80,
                color: AppColors.textSecondary.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty ? 'No rides found' : 'No rides yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try a different search term'
                    : 'Tap "Start New Ride" from Dashboard to begin',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final ride = filteredRides[index];
          return _buildRideCard(
            ride: ride,
            title: ride.name,
            distance: _formatDistance(ride.distance),
            duration: _formatDuration(ride.duration),
            date: _formatDate(ride.startTime),
            type: ride.type,
            icon: _getRideIcon(ride),
          );
        },
        childCount: filteredRides.length,
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final rideDate = DateTime(date.year, date.month, date.day);

    if (rideDate == today) {
      return 'Today, ${DateFormat.jm().format(date)}';
    } else if (rideDate == yesterday) {
      return 'Yesterday, ${DateFormat.jm().format(date)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }

  IconData _getRideIcon(Ride ride) {
    final hour = ride.startTime.hour;
    if (ride.type == 'Commute') {
      return Icons.business;
    } else if (hour < 12) {
      return Icons.wb_sunny_outlined;
    } else if (hour < 17) {
      return Icons.wb_cloudy_outlined;
    } else {
      return Icons.nightlight_outlined;
    }
  }



  Widget _buildRideCard({
    required Ride ride,
    required String title,
    required String distance,
    required String duration,
    required String date,
    required String type,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RideDetailPage(ride: ride),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primaryOrange, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: type == 'Commute'
                                  ? AppColors.primaryPurple.withOpacity(0.1)
                                  : AppColors.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: type == 'Commute' ? AppColors.primaryPurple : AppColors.primaryOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.straighten, size: 14, color: AppColors.textSecondary.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(
                            distance,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time, size: 14, color: AppColors.textSecondary.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(
                            duration,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.lightGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
