import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'emergency_requests_screen.dart';

/// Screen displaying all blood donation responses submitted by the currently logged-in donor.
class MyResponsesScreen extends StatefulWidget {
  const MyResponsesScreen({super.key});

  static const Color primaryColor = Color(0xFFC62828); // Deep Crimson Red
  static const Color surfaceColor = Color(0xFFF9FAFB);
  static const Color cardBorderColor = Color(0xFFE5E7EB);
  static const Color textPrimaryColor = Color(0xFF1F2937);
  static const Color textSecondaryColor = Color(0xFF6B7280);

  /// Formats date safely from Timestamp, DateTime, String, int, or null.
  static String formatResponseDate(dynamic value) {
    if (value == null) return 'Recently submitted';

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

    if (date == null) return 'Recently submitted';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final monthStr = months[date.month - 1];
    final dayStr = date.day.toString().padLeft(2, '0');
    final hourStr = date.hour.toString().padLeft(2, '0');
    final minuteStr = date.minute.toString().padLeft(2, '0');
    return '$dayStr $monthStr ${date.year} at $hourStr:$minuteStr';
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

  /// Returns visual configuration (label, colors, icon) for a response status.
  static StatusBadgeConfig getStatusConfig(dynamic rawStatus) {
    final status = rawStatus?.toString().trim().toLowerCase() ?? '';

    switch (status) {
      case 'accepted':
      case 'approved':
        return const StatusBadgeConfig(
          label: 'Accepted',
          textColor: Color(0xFF15803D),
          backgroundColor: Color(0xFFDCFCE7),
          borderColor: Color(0xFF86EFAC),
          icon: Icons.check_circle_outline_rounded,
          description: 'The hospital coordinator has accepted your donation offer. They will contact you shortly.',
        );
      case 'rejected':
      case 'declined':
        return const StatusBadgeConfig(
          label: 'Rejected',
          textColor: Color(0xFFDC2626),
          backgroundColor: Color(0xFFFEE2E2),
          borderColor: Color(0xFFFCA5A5),
          icon: Icons.cancel_outlined,
          description: 'This request has already been fulfilled or cannot proceed at this time. Thank you for your willingness to help.',
        );
      case 'pending':
      default:
        return const StatusBadgeConfig(
          label: 'Pending Review',
          textColor: Color(0xFFB45309),
          backgroundColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFFDE68A),
          icon: Icons.hourglass_empty_rounded,
          description: 'Your response has been sent to the hospital and is awaiting review by the medical team.',
        );
    }
  }

  @override
  State<MyResponsesScreen> createState() => _MyResponsesScreenState();
}

class _MyResponsesScreenState extends State<MyResponsesScreen> {
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

  Stream<QuerySnapshot<Map<String, dynamic>>>? _getResponsesStream(String uid) {
    try {
      return FirebaseFirestore.instance
          .collection('donor_responses')
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
        backgroundColor: MyResponsesScreen.surfaceColor,
        appBar: AppBar(
          title: const Text(
            'My Responses',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
          ),
          backgroundColor: MyResponsesScreen.primaryColor,
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
                  color: MyResponsesScreen.textSecondaryColor,
                ),
                SizedBox(height: 16),
                Text(
                  'Please Sign In',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MyResponsesScreen.textPrimaryColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Sign in to your donor account to track your submitted blood donation responses.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: MyResponsesScreen.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final stream = _getResponsesStream(currentUser.uid);

    if (stream == null) {
      return Scaffold(
        backgroundColor: MyResponsesScreen.surfaceColor,
        appBar: AppBar(
          title: const Text(
            'My Responses',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
          ),
          backgroundColor: MyResponsesScreen.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Database is not connected.',
            style: TextStyle(
              color: MyResponsesScreen.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MyResponsesScreen.surfaceColor,
      appBar: AppBar(
        title: const Text(
          'My Responses',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
        backgroundColor: MyResponsesScreen.primaryColor,
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
                      color: MyResponsesScreen.primaryColor,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading your responses...',
                      style: TextStyle(
                        fontSize: 14,
                        color: MyResponsesScreen.textSecondaryColor,
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
                        'Unable to load your responses',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: MyResponsesScreen.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We encountered an issue retrieving your response history. Please check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: MyResponsesScreen.textSecondaryColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _retryLoading,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyResponsesScreen.primaryColor,
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

            // 3. Sort by respondedAt descending in memory (newest first, nulls at the end)
            // This avoids requiring a Firestore composite index while keeping sorting reliable.
            docs.sort((a, b) {
              final dateA = MyResponsesScreen.parseDateTime(a.data()['respondedAt']);
              final dateB = MyResponsesScreen.parseDateTime(b.data()['respondedAt']);

              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              return dateB.compareTo(dateA);
            });

            // 4. Empty State
            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: MyResponsesScreen.primaryColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.assignment_outlined,
                          size: 56,
                          color: MyResponsesScreen.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No Responses Yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: MyResponsesScreen.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "You haven't responded to any emergency blood requests yet.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: MyResponsesScreen.textSecondaryColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EmergencyRequestsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.emergency_rounded, size: 18),
                        label: const Text('View Emergency Requests'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyResponsesScreen.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
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

            // 5. Response Cards List View
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();

                final rawBloodGroup = data['bloodGroup'] as String? ?? data['requestBloodGroup'] as String?;
                final bloodGroup = (rawBloodGroup != null && rawBloodGroup.trim().isNotEmpty)
                    ? rawBloodGroup.trim()
                    : 'Blood Donor';

                final rawHospital = data['hospitalName'] as String?;
                final hospitalName = (rawHospital != null && rawHospital.trim().isNotEmpty)
                    ? rawHospital.trim()
                    : 'Emergency Blood Request';

                final rawRequestId = data['requestId'] as String?;
                final requestIdDisplay = (rawRequestId != null && rawRequestId.trim().isNotEmpty)
                    ? (rawRequestId.length > 10 ? 'Ref: #${rawRequestId.substring(0, 8)}...' : 'Ref: #$rawRequestId')
                    : null;

                final rawStatus = data['status'];
                final statusConfig = MyResponsesScreen.getStatusConfig(rawStatus);
                final respondedDateStr = MyResponsesScreen.formatResponseDate(data['respondedAt']);

                return Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: MyResponsesScreen.cardBorderColor),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Blood Group Badge + Status Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: MyResponsesScreen.primaryColor,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: MyResponsesScreen.primaryColor.withValues(alpha: 0.25),
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
                                    bloodGroup,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Status Badge
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
                                  const SizedBox(width: 5),
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

                        const SizedBox(height: 12),

                        // Hospital Name
                        Row(
                          children: [
                            const Icon(
                              Icons.local_hospital_rounded,
                              size: 18,
                              color: MyResponsesScreen.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hospitalName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: MyResponsesScreen.textPrimaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Response status note
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: MyResponsesScreen.cardBorderColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 15,
                                color: statusConfig.textColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  statusConfig.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: MyResponsesScreen.textSecondaryColor,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        const Divider(
                          height: 1,
                          color: MyResponsesScreen.cardBorderColor,
                        ),
                        const SizedBox(height: 10),

                        // Footer: Timestamp & Request Reference
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: MyResponsesScreen.textSecondaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  respondedDateStr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: MyResponsesScreen.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                            if (requestIdDisplay != null)
                              Text(
                                requestIdDisplay,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: MyResponsesScreen.textSecondaryColor,
                                ),
                              ),
                          ],
                        ),
                      ],
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
}

/// Visual style configuration for a response status badge.
class StatusBadgeConfig {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;
  final String description;

  const StatusBadgeConfig({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
    required this.description,
  });
}
