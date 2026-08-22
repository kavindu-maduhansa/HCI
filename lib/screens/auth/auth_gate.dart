import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import '../donor/donor_home_screen.dart';
import '../recipient/recipient_home_screen.dart';
import '../hospital/hospital_home_screen.dart';
import '../coordinator/organisation_home_screen.dart';

/// Listens to Firebase Auth state and routes users based on their Firestore role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Checking initial Firebase authentication state
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingView(message: 'Checking authentication...');
        }

        final user = authSnapshot.data;

        // User is not authenticated -> show LoginScreen
        if (user == null) {
          return const LoginScreen();
        }

        // User is authenticated -> stream user profile document from Firestore
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userDocSnapshot) {
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingView(message: 'Loading account information...');
            }

            if (userDocSnapshot.hasError) {
              return _AuthErrorView(
                message: 'Unable to load your account information.',
                details: userDocSnapshot.error?.toString(),
              );
            }

            final doc = userDocSnapshot.data;

            // Document does not exist in users/{uid}
            if (doc == null || !doc.exists) {
              return const _AuthErrorView(
                message: 'Account profile document not found in database.',
              );
            }

            final data = doc.data();
            final rawRole = data?['role'] as String?;

            // Role field is missing or empty
            if (rawRole == null || rawRole.trim().isEmpty) {
              return const _AuthErrorView(
                message: 'Account role is not assigned.',
              );
            }

            final role = rawRole.trim().toLowerCase();

            // Route to appropriate role area
            switch (role) {
              case 'donor':
                return const DonorHomeScreen();
              case 'recipient':
                return const RecipientHomeScreen();
              case 'hospital':
                return const HospitalHomeScreen();
              case 'organisation':
              case 'organization':
              case 'coordinator':
                return const OrganisationHomeScreen();
              default:
                return _AuthErrorView(
                  message: 'Unknown role assigned: "$rawRole".',
                );
            }
          },
        );
      },
    );
  }
}

/// Simple loading screen while checking auth state or fetching Firestore role.
class _AuthLoadingView extends StatelessWidget {
  final String message;

  const _AuthLoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFC62828);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.water_drop_rounded,
                size: 40,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: primaryColor,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'Blood Donation HCI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error view displayed when user document or role cannot be loaded.
class _AuthErrorView extends StatelessWidget {
  final String message;
  final String? details;

  const _AuthErrorView({
    required this.message,
    this.details,
  });

  Future<void> _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFC62828);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 44,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Account Notice',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _handleSignOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        'Return to Login',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
