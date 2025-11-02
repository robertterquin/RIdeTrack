import 'package:flutter/material.dart';

/// Splash screen shown when app launches
/// Displays RideTrack logo and branding before navigating to auth
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup fade-in animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _controller.forward();
    
    // Navigate to auth after 3 seconds
    _navigateToAuth();
  }

  Future<void> _navigateToAuth() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      // TODO: Replace with your auth route navigation
      // Example: Navigator.of(context).pushReplacementNamed('/auth/login');
      // For now, we'll use a placeholder
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Center(
            child: Image.asset(
              'assets/images/BikeTrack.png',
              width: 320,
              height: 320,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
