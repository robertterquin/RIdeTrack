import 'package:flutter/material.dart';
import 'package:bikeapp/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bikeapp/presentation/pages/ride/unified_ride_page.dart';
import 'package:bikeapp/presentation/pages/ride/ride_detail_page.dart';
import 'package:bikeapp/data/repositories/ride_repository.dart';
import 'package:bikeapp/data/models/ride.dart';
import 'package:intl/intl.dart';

/// Dashboard / Home Page
/// Shows user's stats summary, recent rides, and quick action buttons
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _userName = 'User';
  String _greeting = 'Good Day';
  bool _isLoadingUser = true;
  final RideRepository _rideRepository = RideRepository();
  List<Ride> _recentRides = [];
  bool _isLoadingRides = true;
  Map<String, dynamic>? _userStats;

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _loadUserData();
    _loadRecentRides();
    _loadUserStats();
  }

  /// Load user data from Firestore
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      print('🔍 Current user: ${user?.uid}');
      
      if (user != null) {
        print('📥 Fetching user data from Firestore...');
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        print('📄 Document exists: ${doc.exists}');
        print('📄 Document data: ${doc.data()}');
        
        if (doc.exists && mounted) {
          final fullName = doc.data()?['name'] ?? 'User';
          print('👤 Full name from Firestore: $fullName');
          
          // Extract first name only (split by space and take first part)
          final firstName = fullName.split(' ').first;
          print('✅ First name extracted: $firstName');
          
          setState(() {
            _userName = firstName;
            _isLoadingUser = false;
          });
        } else {
          print('⚠️ Document does not exist or widget unmounted');
          setState(() {
            _isLoadingUser = false;
          });
        }
      } else {
        print('⚠️ No user is currently logged in');
        setState(() {
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  /// Update greeting based on time of day
  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
  }

  /// Load recent rides from Firestore
  Future<void> _loadRecentRides() async {
    print('🔄 Loading recent rides...');
    setState(() {
      _isLoadingRides = true;
    });

    try {
      final rides = await _rideRepository.getRecentRides();
      print('📊 Dashboard received ${rides.length} rides');
      if (mounted) {
        setState(() {
          _recentRides = rides;
          _isLoadingRides = false;
        });
      }
    } catch (e) {
      print('❌ Error loading recent rides: $e');
      if (mounted) {
        setState(() {
          _isLoadingRides = false;
        });
      }
    }
  }

  /// Load user stats from Firestore
  Future<void> _loadUserStats() async {
    print('📊 Loading user stats...');
    try {
      final stats = await _rideRepository.getUserStats();
      print('📈 User stats: $stats');
      if (mounted && stats != null) {
        setState(() {
          _userStats = stats;
        });
      }
    } catch (e) {
      print('❌ Error loading user stats: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Header with Rounded Bottom Corners
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Top Row: Greeting on the left, action icons on the right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Greeting placed on the left and vertically aligned with icons
                          Expanded(
                            child: _isLoadingUser
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '$_greeting, ',
                                          style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 18, fontWeight: FontWeight.w500),
                                        ),
                                        TextSpan(
                                          text: _userName,
                                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                                padding: const EdgeInsets.all(8),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(Icons.person_outline, color: Colors.white, size: 28),
                                padding: const EdgeInsets.all(8),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            // Stats Summary Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'Total Rides',
                        _userStats != null ? '${_userStats!['totalRides']}' : '0',
                        Icons.directions_bike,
                      ),
                      _buildStatItem(
                        'Distance',
                        _userStats != null
                            ? _formatDistance(_userStats!['totalDistance'])
                            : '0 km',
                        Icons.straighten,
                      ),
                      _buildStatItem(
                        'Time',
                        _userStats != null
                            ? _formatDuration(_userStats!['totalTime'])
                            : '0m',
                        Icons.access_time,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // New Ride Action Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const UnifiedRidePage(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: AppColors.purpleGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.directions_bike,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start New Ride',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Track your journey',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Weekly Progress Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'This Week',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: Navigate to statistics
                        },
                        child: const Text(
                          'See All',
                          style: TextStyle(color: AppColors.primaryOrange),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildWeeklyStatRow('Distance', '45 km', '80%', 0.8),
                        const SizedBox(height: 16),
                        _buildWeeklyStatRow('Rides', '4 rides', '67%', 0.67),
                        const SizedBox(height: 16),
                        _buildWeeklyStatRow('Calories', '1,250 kcal', '90%', 0.9),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Recent Rides Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Rides',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          DefaultTabController.of(context).animateTo(1);
                        },
                        child: const Text(
                          'View All',
                          style: TextStyle(color: AppColors.primaryOrange),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingRides)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(color: AppColors.primaryOrange),
                      ),
                    )
                  else if (_recentRides.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_bike_outlined,
                              size: 48,
                              color: AppColors.textSecondary.withOpacity(0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No rides yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Start New Ride" to begin',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._recentRides.map((ride) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildRideCard(
                          ride: ride,
                          title: ride.name,
                          stats: '${_formatDistance(ride.distance)} • ${_formatDuration(ride.duration)}',
                          time: _formatDate(ride.startTime),
                          icon: _getRideIcon(ride),
                        ),
                      );
                    }),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyStatRow(String label, String value, String percentage, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.lightGrey.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              percentage,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryOrange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRideCard({
    required Ride ride,
    required String title,
    required String stats,
    required String time,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  child: Icon(
                    icon,
                    color: AppColors.primaryOrange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stats,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.lightGrey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
