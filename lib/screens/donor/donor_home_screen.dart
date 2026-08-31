import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'donor_profile_screen.dart';
import 'emergency_requests_screen.dart';

/// Modern, professional Blood Donor Dashboard for mobile healthcare applications.
class DonorHomeScreen extends StatelessWidget {
  const DonorHomeScreen({super.key});

  static const Color primaryColor = Color(0xFFC62828); // Deep Crimson Red
  static const Color surfaceColor = Color(0xFFF9FAFB);
  static const Color cardBorderColor = Color(0xFFE5E7EB);
  static const Color textPrimaryColor = Color(0xFF1F2937);
  static const Color textSecondaryColor = Color(0xFF6B7280);

  User? get _currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _getUserStream(String uid) {
    try {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
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

  /// Extracts user's first name safely from fullName.
  String _getFirstName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) {
      return 'Donor';
    }
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : 'Donor';
  }

  /// Generates a friendly greeting based on local device time.
  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  /// Formats last donation date safely.
  String _formatLastDonationDate(dynamic value) {
    if (value == null) return 'No record';

    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) return 'No record';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final monthStr = months[date.month - 1];
    return '${date.day} $monthStr ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: const Text(
          'Donor Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
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
      body: user == null
          ? _buildDashboardContent(context, null)
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _getUserStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: primaryColor,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading dashboard...',
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final data = snapshot.data?.data();
                return _buildDashboardContent(context, data);
              },
            ),
    );
  }

  /// Builds main dashboard scrollable content using user profile data.
  Widget _buildDashboardContent(BuildContext context, Map<String, dynamic>? data) {
    final fullName = data?['fullName'] as String?;
    final firstName = _getFirstName(fullName);
    final isAvailable = (data?['isAvailable'] as bool?) ?? false;

    final rawBloodGroup = data?['bloodGroup'] as String?;
    final bloodGroup = (rawBloodGroup != null && rawBloodGroup.trim().isNotEmpty)
        ? rawBloodGroup.trim()
        : 'Not set';

    final rawLocation = data?['location'] as String?;
    final location = (rawLocation != null && rawLocation.trim().isNotEmpty)
        ? rawLocation.trim()
        : 'Not set';

    final lastDonation = _formatLastDonationDate(data?['lastDonationDate']);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Personalized Welcome Section
          _buildWelcomeSection(firstName),

          const SizedBox(height: 18),

          // 2. Availability Status Card
          _buildAvailabilityCard(isAvailable),

          const SizedBox(height: 24),

          // 3. Donor Information Summary
          _buildProfileSummary(bloodGroup, location, lastDonation),

          const SizedBox(height: 24),

          // 4. Quick Actions Grid
          _buildQuickActions(context),

          const SizedBox(height: 24),

          // 5. Emergency Request Call-to-Action
          _buildEmergencyCTA(context),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 1. Personalized Welcome Section
  Widget _buildWelcomeSection(String firstName) {
    final greeting = _getTimeGreeting();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$greeting, $firstName 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Your small act of kindness can save a life.',
          style: TextStyle(
            fontSize: 14,
            color: textSecondaryColor,
          ),
        ),
      ],
    );
  }

  /// 2. Availability Status Card
  Widget _buildAvailabilityCard(bool isAvailable) {
    final statusColor = isAvailable ? const Color(0xFF2E7D32) : const Color(0xFFDC2626);
    final bgColor = isAvailable ? const Color(0xFFE8F5E9) : const Color(0xFFFEE2E2);
    final borderColor = isAvailable ? const Color(0xFFA5D6A7) : const Color(0xFFFCA5A5);
    final title = isAvailable ? 'Available to Donate' : 'Currently Unavailable';
    final subtitle = isAvailable
        ? 'You are currently available to help save lives.'
        : 'You are currently not available for donation.';
    final icon = isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: Icon(
              icon,
              color: statusColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Donor Information Summary
  Widget _buildProfileSummary(String bloodGroup, String location, String lastDonation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Donation Profile',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.water_drop_rounded,
                iconColor: primaryColor,
                label: 'Blood Group',
                value: bloodGroup,
                isHighlighted: bloodGroup != 'Not set',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.location_on_rounded,
                iconColor: const Color(0xFF2563EB),
                label: 'Location',
                value: location,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.calendar_today_rounded,
                iconColor: const Color(0xFF059669),
                label: 'Last Donation',
                value: lastDonation,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Single compact info summary card
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
              color: isHighlighted ? primaryColor : textPrimaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 4. Quick Actions Grid
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _buildActionCard(
              icon: Icons.emergency_rounded,
              iconColor: primaryColor,
              title: 'Emergency Requests',
              description: 'View urgent blood requests',
              onTap: () => _navigateToEmergencyRequests(context),
            ),
            _buildActionCard(
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF2563EB),
              title: 'My Profile',
              description: 'View and update your profile',
              onTap: () => _navigateToProfile(context),
            ),
            _buildActionCard(
              icon: Icons.assignment_turned_in_outlined,
              iconColor: const Color(0xFF7C3AED),
              title: 'My Responses',
              description: 'Track your responses',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('My Responses will be available soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            _buildActionCard(
              icon: Icons.history_rounded,
              iconColor: const Color(0xFF059669),
              title: 'Donation History',
              description: 'View your donation records',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Donation History will be available soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Single clickable action card
  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: cardBorderColor),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: textSecondaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 5. Emergency Request Call-to-Action
  Widget _buildEmergencyCTA(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFB71C1C),
            Color(0xFFD32F2F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Emergency Blood Requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Someone may need your help right now. Check active requests in your area.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToEmergencyRequests(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View Emergency Requests',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
