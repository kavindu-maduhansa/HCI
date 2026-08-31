import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Screen displaying the history of blood donations made by the currently logged-in donor.
class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  static const Color primaryColor = Color(0xFFC62828); // Deep Crimson Red
  static const Color surfaceColor = Color(0xFFF9FAFB);
  static const Color cardBorderColor = Color(0xFFE5E7EB);
  static const Color textPrimaryColor = Color(0xFF1F2937);
  static const Color textSecondaryColor = Color(0xFF6B7280);

  /// Helper to safely format donation date from Timestamp, DateTime, String, int, or null.
  static String formatDonationDate(dynamic value) {
    if (value == null) return 'Date not available';

    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    } else if (value is int) {
      try {
        date = DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        date = null;
      }
    }

    if (date == null) return 'Date not available';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final monthStr = months[date.month - 1];
    final dayStr = date.day.toString().padLeft(2, '0');
    return '$dayStr $monthStr ${date.year}';
  }

  /// Converts dynamic timestamp to DateTime for client-side sorting.
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Returns visual configuration (label, colors, icon) for a donation status.
  static DonationStatusConfig getStatusConfig(dynamic rawStatus) {
    final status = rawStatus?.toString().trim().toLowerCase() ?? '';

    switch (status) {
      case 'completed':
      case 'done':
      case 'success':
        return const DonationStatusConfig(
          label: 'Completed',
          textColor: Color(0xFF15803D),
          backgroundColor: Color(0xFFDCFCE7),
          borderColor: Color(0xFF86EFAC),
          icon: Icons.check_circle_rounded,
        );
      case 'verified':
      case 'approved':
        return const DonationStatusConfig(
          label: 'Verified',
          textColor: Color(0xFF0369A1),
          backgroundColor: Color(0xFFE0F2FE),
          borderColor: Color(0xFF7DD3FC),
          icon: Icons.verified_rounded,
        );
      case 'pending':
      case 'processing':
        return const DonationStatusConfig(
          label: 'Pending',
          textColor: Color(0xFFB45309),
          backgroundColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFFDE68A),
          icon: Icons.schedule_rounded,
        );
      case 'cancelled':
      case 'canceled':
      case 'rejected':
        return const DonationStatusConfig(
          label: 'Cancelled',
          textColor: Color(0xFFDC2626),
          backgroundColor: Color(0xFFFEE2E2),
          borderColor: Color(0xFFFCA5A5),
          icon: Icons.cancel_outlined,
        );
      default:
        final displayLabel = rawStatus != null && rawStatus.toString().trim().isNotEmpty
            ? rawStatus.toString().trim()
            : 'Unknown';
        return DonationStatusConfig(
          label: displayLabel,
          textColor: const Color(0xFF4B5563),
          backgroundColor: const Color(0xFFF3F4F6),
          borderColor: const Color(0xFFE5E7EB),
          icon: Icons.help_outline_rounded,
        );
    }
  }

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  int _streamKey = 0;

  User? get _currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  void _retryLoading() {
    setState(() {
      _streamKey++;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _getHistoryStream(String uid) {
    try {
      return FirebaseFirestore.instance
          .collection('donation_history')
          .where('donorId', isEqualTo: uid)
          .snapshots();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: DonationHistoryScreen.surfaceColor,
        appBar: AppBar(
          title: const Text(
            'Donation History',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
          ),
          backgroundColor: DonationHistoryScreen.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  size: 56,
                  color: DonationHistoryScreen.textSecondaryColor,
                ),
                SizedBox(height: 16),
                Text(
                  'Please Sign In',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DonationHistoryScreen.textPrimaryColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Sign in to your donor account to view your complete blood donation history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: DonationHistoryScreen.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final stream = _getHistoryStream(currentUser.uid);

    if (stream == null) {
      return Scaffold(
        backgroundColor: DonationHistoryScreen.surfaceColor,
        appBar: AppBar(
          title: const Text(
            'Donation History',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
          ),
          backgroundColor: DonationHistoryScreen.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Database is not connected.',
            style: TextStyle(
              color: DonationHistoryScreen.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DonationHistoryScreen.surfaceColor,
      appBar: AppBar(
        title: const Text(
          'Donation History',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
        backgroundColor: DonationHistoryScreen.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: KeyedSubtree(
        key: ValueKey(_streamKey),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            // 1. Loading State
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: DonationHistoryScreen.primaryColor,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading donation history...',
                      style: TextStyle(
                        fontSize: 14,
                        color: DonationHistoryScreen.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            // 2. Error State
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          size: 46,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Unable to load donation history.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: DonationHistoryScreen.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We encountered an issue retrieving your donation records. Please check your internet connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: DonationHistoryScreen.textSecondaryColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _retryLoading,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DonationHistoryScreen.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs.toList() ?? [];

            // 3. Sort records by donationDate descending in memory
            // (falls back to createdAt or nulls last to avoid requiring Firestore composite index)
            docs.sort((a, b) {
              final dataA = a.data();
              final dataB = b.data();

              final dateA = DonationHistoryScreen.parseDateTime(dataA['donationDate']) ??
                  DonationHistoryScreen.parseDateTime(dataA['createdAt']);
              final dateB = DonationHistoryScreen.parseDateTime(dataB['donationDate']) ??
                  DonationHistoryScreen.parseDateTime(dataB['createdAt']);

              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              return dateB.compareTo(dateA);
            });

            // 4. Empty State
            if (docs.isEmpty) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Summary section showing 0 donations
                    _buildSummaryCard(totalDonations: 0, lastDonationDate: 'No donations yet'),
                    const SizedBox(height: 48),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: DonationHistoryScreen.primaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        size: 56,
                        color: DonationHistoryScreen.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Donation History',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: DonationHistoryScreen.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You have not completed any blood donations yet. Your completed donations will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: DonationHistoryScreen.textSecondaryColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Calculate summary statistics
            final totalDonations = docs.length;
            final newestRecord = docs.first.data();
            final lastDonationDate = DonationHistoryScreen.formatDonationDate(
              newestRecord['donationDate'] ?? newestRecord['createdAt'],
            );

            // 5. Scrollable Content with Summary Section and Donation Cards
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              itemCount: docs.length + 1, // +1 for the summary header card
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildSummaryCard(
                      totalDonations: totalDonations,
                      lastDonationDate: lastDonationDate,
                    ),
                  );
                }

                final doc = docs[index - 1];
                final data = doc.data();

                final rawBloodGroup = data['bloodGroup'] as String?;
                final bloodGroup = (rawBloodGroup != null && rawBloodGroup.trim().isNotEmpty)
                    ? rawBloodGroup.trim()
                    : 'Blood Donation';

                final rawHospital = (data['hospitalName'] ?? data['organizationName']) as String?;
                final hospitalName = (rawHospital != null && rawHospital.trim().isNotEmpty)
                    ? rawHospital.trim()
                    : 'Hospital / Organization not specified';

                final rawLocation = data['location'] as String?;
                final location = (rawLocation != null && rawLocation.trim().isNotEmpty)
                    ? rawLocation.trim()
                    : 'Location not specified';

                final rawStatus = data['status'];
                final statusConfig = DonationHistoryScreen.getStatusConfig(rawStatus);

                final donationDateStr = DonationHistoryScreen.formatDonationDate(
                  data['donationDate'] ?? data['createdAt'],
                );

                final rawNotes = data['notes'] as String?;
                final hasNotes = rawNotes != null && rawNotes.trim().isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: DonationHistoryScreen.cardBorderColor),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Blood Group Badge + Donation Status Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: DonationHistoryScreen.primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: DonationHistoryScreen.primaryColor.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.water_drop_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      bloodGroup.endsWith('Blood') || bloodGroup == 'Blood Donation'
                                          ? bloodGroup
                                          : '$bloodGroup Blood',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Status Chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusConfig.backgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: statusConfig.borderColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      statusConfig.icon,
                                      size: 14,
                                      color: statusConfig.textColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      statusConfig.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: statusConfig.textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Donation Date
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: DonationHistoryScreen.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                donationDateStr,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: DonationHistoryScreen.textPrimaryColor,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Hospital Name
                          Row(
                            children: [
                              const Icon(
                                Icons.local_hospital_outlined,
                                size: 16,
                                color: DonationHistoryScreen.textSecondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hospitalName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: DonationHistoryScreen.textPrimaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Location
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: DonationHistoryScreen.textSecondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  location,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: DonationHistoryScreen.textSecondaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          // Optional Notes
                          if (hasNotes) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: DonationHistoryScreen.cardBorderColor),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.notes_rounded,
                                    size: 14,
                                    color: DonationHistoryScreen.textSecondaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      rawNotes.trim(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: DonationHistoryScreen.textSecondaryColor,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Top summary card displaying donation statistics.
  Widget _buildSummaryCard({
    required int totalDonations,
    required String lastDonationDate,
  }) {
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
            color: DonationHistoryScreen.primaryColor.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total Donations Box
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.volunteer_activism_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Total Donations',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalDonations',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  totalDonations == 1 ? 'Life-saving donation' : 'Life-saving donations',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 50,
            width: 1,
            color: Colors.white24,
          ),
          const SizedBox(width: 16),
          // Last Donation Box
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Most Recent',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  lastDonationDate,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Record Verified',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual style configuration for a donation status badge.
class DonationStatusConfig {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;

  const DonationStatusConfig({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
  });
}
