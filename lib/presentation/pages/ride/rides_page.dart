import 'package:flutter/material.dart';
import 'package:bikeapp/core/constants/app_colors.dart';

/// Rides Page
/// Shows ride history, filters, and allows starting new rides
class RidesPage extends StatefulWidget {
  const RidesPage({super.key});

  @override
  State<RidesPage> createState() => _RidesPageState();
}

class _RidesPageState extends State<RidesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              floating: true,
              pinned: true,
              title: const Text(
                'My Rides',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: AppColors.textPrimary),
                  onPressed: () {
                    // TODO: Implement search
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.white),
                            SizedBox(width: 12),
                            Text('Search coming soon!'),
                          ],
                        ),
                        backgroundColor: AppColors.primaryOrange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list, color: AppColors.textPrimary),
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppColors.primaryOrange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.primaryOrange,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      tabs: const [
                        Tab(text: 'All'),
                        Tab(text: 'Commute'),
                        Tab(text: 'Recreation'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRidesList('All'),
            _buildRidesList('Commute'),
            _buildRidesList('Recreation'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to start ride page
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Start Ride feature coming soon!'),
                ],
              ),
              backgroundColor: AppColors.primaryOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        backgroundColor: AppColors.primaryOrange,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Ride', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildRidesList(String category) {
    // Mock ride data - will be replaced with real data from Firestore
    // Apply time filter based on _selectedFilter
    final rides = _getMockRides(category);

    if (rides.isEmpty) {
      return Center(
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
              'No rides found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'All'
                  ? 'Tap "Start Ride" to record your first ride'
                  : 'No rides in $_selectedFilter',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
      itemCount: rides.length,
      itemBuilder: (context, index) {
        final ride = rides[index];
        return _buildRideCard(
          title: ride['title']!,
          distance: ride['distance']!,
          duration: ride['duration']!,
          date: ride['date']!,
          type: ride['type']!,
          icon: ride['icon'] as IconData,
        );
      },
    );
  }

  List<Map<String, dynamic>> _getMockRides(String category) {
    final allRides = [
      {
        'title': 'Morning Commute',
        'distance': '12.5 km',
        'duration': '35 min',
        'date': 'Today, 8:30 AM',
        'type': 'Commute',
        'icon': Icons.wb_sunny_outlined,
      },
      {
        'title': 'Evening Ride',
        'distance': '18.2 km',
        'duration': '52 min',
        'date': 'Yesterday, 6:15 PM',
        'type': 'Recreation',
        'icon': Icons.nightlight_outlined,
      },
      {
        'title': 'Weekend Trail',
        'distance': '32.8 km',
        'duration': '1h 45m',
        'date': 'Nov 7, 10:00 AM',
        'type': 'Recreation',
        'icon': Icons.terrain,
      },
      {
        'title': 'Office Commute',
        'distance': '11.3 km',
        'duration': '32 min',
        'date': 'Nov 6, 8:45 AM',
        'type': 'Commute',
        'icon': Icons.business,
      },
      {
        'title': 'Lunch Break Ride',
        'distance': '8.5 km',
        'duration': '25 min',
        'date': 'Nov 6, 12:30 PM',
        'type': 'Recreation',
        'icon': Icons.restaurant,
      },
      {
        'title': 'City Tour',
        'distance': '25.4 km',
        'duration': '1h 18m',
        'date': 'Nov 5, 3:00 PM',
        'type': 'Recreation',
        'icon': Icons.location_city,
      },
    ];

    if (category == 'All') return allRides;
    return allRides.where((ride) => ride['type'] == category).toList();
  }

  Widget _buildRideCard({
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
            // TODO: Navigate to ride details
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Ride details for "$title" coming soon!')),
                  ],
                ),
                backgroundColor: AppColors.primaryPurple,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
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
