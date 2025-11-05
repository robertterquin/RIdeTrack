import 'package:flutter/material.dart';
import 'package:bikeapp/presentation/pages/dashboard/dashboard_page.dart';
import 'package:bikeapp/presentation/pages/ride/rides_page.dart';
import 'package:bikeapp/presentation/pages/goals/goals_page.dart';
import 'package:bikeapp/presentation/pages/statistics/statistics_page.dart';
import 'package:bikeapp/presentation/pages/profile/profile_page.dart';
import 'package:bikeapp/presentation/widgets/bottom_navbar/bottom_navbar.dart';

/// Main navigation container with bottom navigation bar
/// Manages 5 tabs: Dashboard, Rides, Goals, Statistics, Profile
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Pages for each tab
  final List<Widget> _pages = const [
    DashboardPage(),
    RidesPage(),
    GoalsPage(),
    StatisticsPage(),
    ProfilePage(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
