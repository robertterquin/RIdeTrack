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
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Profile Picture
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: ClipOval(
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.white.withOpacity(0.3),
                                  child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                      ? Image.network(
                                          _profileImageUrl!,
                                          fit: BoxFit.cover,
                                          width: 100,
                                          height: 100,
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
                                                  fontSize: 40,
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
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _userName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userEmail,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Stats Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.directions_bike,
                            value: _totalRides.toString(),
                            label: 'Total Rides',
                            color: AppColors.primaryOrange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.straighten,
                            value: '${_totalDistance.toStringAsFixed(1)} km',
                            label: 'Distance',
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.access_time,
                            value: _formatDuration(_totalTime),
                            label: 'Time',
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Achievements Section
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
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _buildSettingsTile(
                                icon: Icons.person_outline,
                                title: 'Edit Profile',
                                subtitle: 'Update your personal information',
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
                              const Divider(height: 1),
                              _buildSettingsTile(
                                icon: Icons.tune,
                                title: 'Preferences',
                                subtitle: 'Units, default ride type',
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
                              const Divider(height: 1),
                              _buildSettingsTile(
                                icon: Icons.notifications_none,
                                title: 'Notifications',
                                subtitle: 'Manage notification preferences',
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
                              const Divider(height: 1),
                              _buildSettingsTile(
                                icon: Icons.lock_outline,
                                title: 'Privacy & Security',
                                subtitle: 'Manage your account security',
                                onTap: () {
                                  Navigator.of(context).pushNamed('/forgot_password');
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // About & Support
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildSettingsTile(
                            icon: Icons.help_outline,
                            title: 'Help & Support',
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
                          const Divider(height: 1),
                          _buildSettingsTile(
                            icon: Icons.info_outline,
                            title: 'About RideTrack',
                            subtitle: 'Version 1.0.0',
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
}
