import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Minimal home placeholder for Donor role.
class DonorHomeScreen extends StatelessWidget {
  const DonorHomeScreen({super.key});

  Future<void> _handleSignOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFC62828);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor Home'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _handleSignOut(context),
          ),
        ],
      ),
      body: Center(
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
                    'Welcome to Blood Donation HCI.\nDonor dashboard features will be implemented in upcoming steps.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => _handleSignOut(context),
                    icon: const Icon(Icons.logout_rounded, color: primaryColor),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
