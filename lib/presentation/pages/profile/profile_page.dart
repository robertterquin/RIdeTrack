import 'package:flutter/material.dart';
import 'package:bikeapp/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bikeapp/core/services/auth_service.dart';
import 'package:bikeapp/presentation/pages/profile/edit_profile_page.dart';

/// Profile Page
/// Shows user profile information, preferences, milestones, and account options
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  String _userName = 'User';
  String _userEmail = '';
  String? _profileImageUrl;
  int _totalRides = 0;
  double _totalDistance = 0.0;
  int _totalTime = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            _userName = data['name'] ?? 'User';
            _userEmail = data['email'] ?? user.email ?? '';
            _profileImageUrl = data['profileImageUrl'];
            _totalRides = data['totalRides'] ?? 0;
            _totalDistance = (data['totalDistance'] ?? 0).toDouble();
            _totalTime = data['totalTime'] ?? 0;
            _isLoading = false;
          });
        } else {
          setState(() {
            _userEmail = user.email ?? '';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Recalculate user stats from actual rides
  Future<void> _recalculateStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      );

      print('Recalculating stats...');

      // Get all rides for this user
      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('userId', isEqualTo: user.uid)
          .get();

      print('Found ${ridesSnapshot.docs.length} rides');

      // Calculate totals from actual rides
      final totalRides = ridesSnapshot.docs.length;
      double totalDistance = 0.0;
      int totalTime = 0;

      for (var doc in ridesSnapshot.docs) {
        final data = doc.data();
        final distance = data['distance'];
        final duration = data['duration'];

        if (distance != null) {
          if (distance is num) {
            totalDistance += distance.toDouble();
          }
        }
        if (duration != null) {
          if (duration is num) {
            totalTime += duration.toInt();
          }
        }
      }

      print('Calculated: $totalRides rides, ${(totalDistance / 1000).toStringAsFixed(2)} km');

      // Update user document with correct totals
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'totalRides': totalRides,
        'totalDistance': totalDistance,
        'totalTime': totalTime,
      });

      // Reload user data
      await _loadUserData();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stats updated: $totalRides rides, ${(totalDistance / 1000).toStringAsFixed(1)} km'),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('Stats recalculated successfully!');
    } catch (e) {
      print('Error recalculating stats: $e');
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recalculating stats: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showRecalculateDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recalculate Stats'),
        content: const Text(
          'This will recalculate your total rides, distance, and time based on your actual ride history. This is useful if your stats seem incorrect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: const Text('Recalculate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _recalculateStats();
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/get_started', (route) => false);
      }
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    width: double.infinity,
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
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: Column(
                          children: [
                            // Profile Picture with modern design
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                    child: ClipOval(
                                      child: Container(
                                        width: 110,
                                        height: 110,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                        ),
                                        child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                            ? Image.network(
                                                _profileImageUrl!,
                                                fit: BoxFit.cover,
                                                width: 110,
                                                height: 110,
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Center(
                                                    child: CircularProgressIndicator(
                                                      value: loadingProgress.expectedTotalBytes != null
                                                          ? loadingProgress.cumulativeBytesLoaded /
                                                              loadingProgress.expectedTotalBytes!
                                                          : null,
                                                      color: Colors.white,
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Center(
                                                    child: Text(
                                                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                                      style: const TextStyle(
                                                        fontSize: 48,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            : Center(
                                                child: Text(
                                                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                                  style: const TextStyle(
                                                    fontSize: 48,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _userName,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _userEmail,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  
                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Achievements',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildAchievementBadge(
                                icon: Icons.emoji_events,
                                label: 'First Ride',
                                isUnlocked: _totalRides > 0,
                              ),
                              _buildAchievementBadge(
                                icon: Icons.local_fire_department,
                                label: '10 Rides',
                                isUnlocked: _totalRides >= 10,
                              ),
                              _buildAchievementBadge(
                                icon: Icons.star,
                                label: '100 km',
                                isUnlocked: _totalDistance >= 100,
                              ),
                              _buildAchievementBadge(
                                icon: Icons.workspace_premium,
                                label: 'Pro Rider',
                                isUnlocked: _totalRides >= 50,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Settings Options
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildModernSettingsTile(
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          subtitle: 'Update your personal information',
                          color: AppColors.primaryOrange,
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const EditProfilePage(),
                              ),
                            );
                            
                            // Reload user data if profile was updated
                            if (result == true) {
                              _loadUserData();
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildModernSettingsTile(
                          icon: Icons.tune,
                          title: 'Preferences',
                          subtitle: 'Units, default ride type',
                          color: AppColors.primaryPurple,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('Preferences coming soon!'),
                                  ],
                                ),
                                backgroundColor: AppColors.primaryPurple,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildModernSettingsTile(
                          icon: Icons.notifications_none,
                          title: 'Notifications',
                          subtitle: 'Manage notification preferences',
                          color: AppColors.primaryOrange,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('Notifications coming soon!'),
                                  ],
                                ),
                                backgroundColor: AppColors.primaryOrange,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildModernSettingsTile(
                          icon: Icons.lock_outline,
                          title: 'Privacy & Security',
                          subtitle: 'Manage your account security',
                          color: AppColors.success,
                          onTap: () {
                            Navigator.of(context).pushNamed('/forgot_password');
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildModernSettingsTile(
                          icon: Icons.refresh,
                          title: 'Recalculate Stats',
                          subtitle: 'Fix incorrect ride statistics',
                          color: AppColors.primaryPurple,
                          onTap: _showRecalculateDialog,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // About & Support
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildModernSettingsTile(
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          subtitle: 'Get help with your account',
                          color: AppColors.primaryPurple,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('Help & Support coming soon!'),
                                  ],
                                ),
                                backgroundColor: AppColors.primaryPurple,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildModernSettingsTile(
                          icon: Icons.info_outline,
                          title: 'About RideTrack',
                          subtitle: 'Version 1.0.0',
                          color: AppColors.primaryOrange,
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'RideTrack',
                              applicationVersion: '1.0.0',
                              applicationIcon: const Icon(
                                Icons.directions_bike,
                                size: 48,
                                color: AppColors.primaryOrange,
                              ),
                              children: [
                                const Text('Personal bike ride tracking app with GPS, goals, and statistics.'),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
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
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge({
    required IconData icon,
    required String label,
    required bool isUnlocked,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnlocked
                ? AppColors.primaryOrange.withOpacity(0.1)
                : AppColors.lightGrey.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isUnlocked ? AppColors.primaryOrange : AppColors.textSecondary.withOpacity(0.3),
            size: 28,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isUnlocked ? AppColors.textPrimary : AppColors.textSecondary.withOpacity(0.5),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryOrange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryOrange, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.lightGrey),
      onTap: onTap,
    );
  }

  Widget _buildModernSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
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
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGrey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
