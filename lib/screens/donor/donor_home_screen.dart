import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'donor_profile_screen.dart';
import 'emergency_requests_screen.dart';

/// Home screen for Donor role with quick navigation to Donor Profile
/// and Emergency Blood Requests.
class DonorHomeScreen extends StatelessWidget {
  const DonorHomeScreen({super.key});

  User? get _currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DonorProfileScreen(),
      ),
    );
  }

  void _navigateToEmergencyRequests(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencyRequestsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFC62828);
    final user = _currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor Home'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Emergency Requests',
            icon: const Icon(Icons.emergency_rounded),
            onPressed: () => _navigateToEmergencyRequests(context),
          ),
          IconButton(
            tooltip: 'My Profile',
            icon: const Icon(Icons.account_circle_rounded),
            onPressed: () => _navigateToProfile(context),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _handleSignOut(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volunteer_activism_rounded,
                        size: 48,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Donor Area',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user?.email ?? 'Logged in as Donor',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to Blood Donation HCI.\nView urgent blood requests or manage your donor profile below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Primary Action: Emergency Blood Requests
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToEmergencyRequests(context),
                        icon: const Icon(Icons.emergency_rounded),
                        label: const Text('Emergency Blood Requests'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Secondary Action: Donor Profile
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToProfile(context),
                        icon: const Icon(Icons.person_rounded, color: primaryColor),
                        label: const Text(
                          'View & Edit Profile',
                          style: TextStyle(color: primaryColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Tertiary Action: Sign Out
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _handleSignOut(context),
                        icon: const Icon(Icons.logout_rounded, color: Color(0xFF6B7280)),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
