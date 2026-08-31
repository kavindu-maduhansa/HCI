import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Screen displaying active emergency blood requests for donors in real time.
class EmergencyRequestsScreen extends StatefulWidget {
  const EmergencyRequestsScreen({super.key});

  static const Color primaryColor = Color(0xFFC62828); // Deep Crimson Red
  static const Color surfaceColor = Color(0xFFF9FAFB);
  static const Color cardBorderColor = Color(0xFFE5E7EB);
  static const Color textPrimaryColor = Color(0xFF1F2937);
  static const Color textSecondaryColor = Color(0xFF6B7280);

  /// Formats date string from Timestamp, DateTime, String, int, or null safely.
  static String formatRequestDate(dynamic value) {
    if (value == null) return 'Not specified';

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

    if (date == null) return 'Not specified';

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

  /// Checks whether a request status represents an active request.
  /// Supports: active, open, pending.
  /// Excludes: completed, cancelled, canceled, closed, fulfilled.
  static bool isActiveStatus(dynamic rawStatus) {
    if (rawStatus == null) return true;
    final status = rawStatus.toString().trim().toLowerCase();
    if (status.isEmpty) return true;

    const inactiveStatuses = {
      'completed',
      'cancelled',
      'canceled',
      'closed',
      'fulfilled',
    };
    if (inactiveStatuses.contains(status)) {
      return false;
    }

    const activeStatuses = {'active', 'open', 'pending'};
    return activeStatuses.contains(status);
  }

  /// Returns visual configuration (label, foreground, background, icon) for an urgency level.
  static UrgencyBadgeConfig getUrgencyConfig(dynamic rawUrgency) {
    final urgency = rawUrgency?.toString().trim().toLowerCase() ?? '';

    switch (urgency) {
      case 'critical':
        return const UrgencyBadgeConfig(
          label: 'Critical',
          textColor: Color(0xFFB71C1C),
          backgroundColor: Color(0xFFFFEBEE),
          borderColor: Color(0xFFFFCDD2),
          icon: Icons.warning_amber_rounded,
        );
      case 'high':
        return const UrgencyBadgeConfig(
          label: 'High Urgency',
          textColor: Color(0xFFE65100),
          backgroundColor: Color(0xFFFFF3E0),
          borderColor: Color(0xFFFFE0B2),
          icon: Icons.priority_high_rounded,
        );
      case 'medium':
        return const UrgencyBadgeConfig(
          label: 'Medium Urgency',
          textColor: Color(0xFFF57F17),
          backgroundColor: Color(0xFFFFFDE7),
          borderColor: Color(0xFFFFF9C4),
          icon: Icons.schedule_rounded,
        );
      case 'low':
        return const UrgencyBadgeConfig(
          label: 'Low Urgency',
          textColor: Color(0xFF2E7D32),
          backgroundColor: Color(0xFFE8F5E9),
          borderColor: Color(0xFFC8E6C9),
          icon: Icons.check_circle_outline_rounded,
        );
      default:
        final displayLabel = rawUrgency != null && rawUrgency.toString().trim().isNotEmpty
            ? rawUrgency.toString().trim()
            : 'Standard';
        return UrgencyBadgeConfig(
          label: displayLabel,
          textColor: const Color(0xFF4B5563),
          backgroundColor: const Color(0xFFF3F4F6),
          borderColor: const Color(0xFFE5E7EB),
          icon: Icons.info_outline_rounded,
        );
    }
  }

  @override
  State<EmergencyRequestsScreen> createState() => _EmergencyRequestsScreenState();
}

class _EmergencyRequestsScreenState extends State<EmergencyRequestsScreen> {
  int _streamKey = 0;

  void _retryLoading() {
    setState(() {
      _streamKey++;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getRequestsStream() {
    return FirebaseFirestore.instance.collection('blood_requests').snapshots();
  }

  void _showRequestDetails(BuildContext context, Map<String, dynamic> data, String requestId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RequestDetailsBottomSheet(
        data: data,
        requestId: requestId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmergencyRequestsScreen.surfaceColor,
      appBar: AppBar(
        title: const Text(
          'Emergency Blood Requests',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
        backgroundColor: EmergencyRequestsScreen.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: KeyedSubtree(
        key: ValueKey(_streamKey),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _getRequestsStream(),
          builder: (context, snapshot) {
            // 1. Loading State
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: EmergencyRequestsScreen.primaryColor,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading emergency requests...',
                      style: TextStyle(
                        fontSize: 14,
                        color: EmergencyRequestsScreen.textSecondaryColor,
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
                        'Unable to load emergency requests',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: EmergencyRequestsScreen.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We encountered an issue while connecting to the blood requests registry. Please check your internet connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: EmergencyRequestsScreen.textSecondaryColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _retryLoading,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EmergencyRequestsScreen.primaryColor,
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

            final allDocs = snapshot.data?.docs ?? [];

            // 3. Filter for active/open/pending requests only
            final activeDocs = allDocs.where((doc) {
              final data = doc.data();
              return EmergencyRequestsScreen.isActiveStatus(data['status']);
            }).toList();

            // 4. Sort by createdAt descending (newest first, nulls at the end)
            activeDocs.sort((a, b) {
              final dateA = EmergencyRequestsScreen.parseDateTime(a.data()['createdAt']);
              final dateB = EmergencyRequestsScreen.parseDateTime(b.data()['createdAt']);

              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              return dateB.compareTo(dateA);
            });

            // 5. Empty State
            if (activeDocs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: EmergencyRequestsScreen.primaryColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.volunteer_activism_outlined,
                          size: 56,
                          color: EmergencyRequestsScreen.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No Emergency Requests',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: EmergencyRequestsScreen.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'There are currently no active blood requests. Please check again later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: EmergencyRequestsScreen.textSecondaryColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // 6. Request List View
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              itemCount: activeDocs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = activeDocs[index];
                final data = doc.data();
                final requestId = doc.id;

                final rawBloodGroup = data['bloodGroup'] as String?;
                final bloodGroup = (rawBloodGroup != null && rawBloodGroup.trim().isNotEmpty)
                    ? rawBloodGroup.trim()
                    : 'Not specified';

                final rawHospital = data['hospitalName'] as String?;
                final hospitalName = (rawHospital != null && rawHospital.trim().isNotEmpty)
                    ? rawHospital.trim()
                    : 'Unknown hospital';

                final rawLocation = data['location'] as String?;
                final location = (rawLocation != null && rawLocation.trim().isNotEmpty)
                    ? rawLocation.trim()
                    : 'Unknown location';

                final urgencyConfig = EmergencyRequestsScreen.getUrgencyConfig(data['urgency']);

                final rawUnits = data['requiredUnits'];
                final unitsString = rawUnits != null
                    ? '$rawUnits ${rawUnits == 1 ? 'Unit' : 'Units'} required'
                    : 'Units: Not specified';

                final rawStatus = data['status'] as String?;
                final statusDisplay = (rawStatus != null && rawStatus.trim().isNotEmpty)
                    ? rawStatus.trim()[0].toUpperCase() + rawStatus.trim().substring(1).toLowerCase()
                    : 'Active';

                return Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: EmergencyRequestsScreen.cardBorderColor),
                  ),
                  color: Colors.white,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showRequestDetails(context, data, requestId),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Blood Group Badge + Urgency Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: EmergencyRequestsScreen.primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: EmergencyRequestsScreen.primaryColor.withValues(alpha: 0.25),
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
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      bloodGroup,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Urgency badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: urgencyConfig.backgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: urgencyConfig.borderColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      urgencyConfig.icon,
                                      size: 14,
                                      color: urgencyConfig.textColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      urgencyConfig.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: urgencyConfig.textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Hospital Name
                          Row(
                            children: [
                              const Icon(
                                Icons.local_hospital_rounded,
                                size: 18,
                                color: EmergencyRequestsScreen.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hospitalName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: EmergencyRequestsScreen.textPrimaryColor,
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
                                color: EmergencyRequestsScreen.textSecondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  location,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: EmergencyRequestsScreen.textSecondaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Required Units
                          Row(
                            children: [
                              const Icon(
                                Icons.medical_services_outlined,
                                size: 16,
                                color: EmergencyRequestsScreen.textSecondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                unitsString,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: EmergencyRequestsScreen.textPrimaryColor,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          const Divider(
                            height: 1,
                            color: EmergencyRequestsScreen.cardBorderColor,
                          ),
                          const SizedBox(height: 10),

                          // Footer: Status Tag & View Details Indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFC8E6C9)),
                                ),
                                child: Text(
                                  statusDisplay,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View Details',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: EmergencyRequestsScreen.primaryColor,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: EmergencyRequestsScreen.primaryColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
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
}

/// Visual style configuration for urgency levels.
class UrgencyBadgeConfig {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;

  const UrgencyBadgeConfig({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
  });
}

/// Modal Bottom Sheet displaying comprehensive information about a selected blood request.
class _RequestDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final String requestId;

  const _RequestDetailsBottomSheet({
    required this.data,
    required this.requestId,
  });

  @override
  Widget build(BuildContext context) {
    final rawBloodGroup = data['bloodGroup'] as String?;
    final bloodGroup = (rawBloodGroup != null && rawBloodGroup.trim().isNotEmpty)
        ? rawBloodGroup.trim()
        : 'Not specified';

    final rawHospital = data['hospitalName'] as String?;
    final hospitalName = (rawHospital != null && rawHospital.trim().isNotEmpty)
        ? rawHospital.trim()
        : 'Unknown hospital';

    final rawLocation = data['location'] as String?;
    final location = (rawLocation != null && rawLocation.trim().isNotEmpty)
        ? rawLocation.trim()
        : 'Unknown location';

    final rawUnits = data['requiredUnits'];
    final unitsString = rawUnits != null
        ? '$rawUnits ${rawUnits == 1 ? 'Unit' : 'Units'}'
        : 'Not specified';

    final rawPatient = data['patientName'] as String?;
    final patientName = (rawPatient != null && rawPatient.trim().isNotEmpty)
        ? rawPatient.trim()
        : 'Not specified';

    final rawContact = data['contactNumber'] as String?;
    final contactNumber = (rawContact != null && rawContact.trim().isNotEmpty)
        ? rawContact.trim()
        : 'Not specified';

    final rawDescription = data['description'] as String?;
    final description = (rawDescription != null && rawDescription.trim().isNotEmpty)
        ? rawDescription.trim()
        : 'No description available';

    final rawStatus = data['status'] as String?;
    final statusDisplay = (rawStatus != null && rawStatus.trim().isNotEmpty)
        ? rawStatus.trim()[0].toUpperCase() + rawStatus.trim().substring(1).toLowerCase()
        : 'Active';

    final urgencyConfig = EmergencyRequestsScreen.getUrgencyConfig(data['urgency']);
    final createdDateStr = EmergencyRequestsScreen.formatRequestDate(data['createdAt']);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 48),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Modal Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Close Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Request Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: EmergencyRequestsScreen.textPrimaryColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Blood Group & Urgency Highlight Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EmergencyRequestsScreen.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: EmergencyRequestsScreen.primaryColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: EmergencyRequestsScreen.primaryColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: EmergencyRequestsScreen.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        bloodGroup,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hospitalName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: EmergencyRequestsScreen.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: urgencyConfig.backgroundColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: urgencyConfig.borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  urgencyConfig.icon,
                                  size: 12,
                                  color: urgencyConfig.textColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  urgencyConfig.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: urgencyConfig.textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Detail List Items Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: EmergencyRequestsScreen.cardBorderColor),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: location,
                    ),
                    const Divider(
                      height: 1,
                      indent: 48,
                      color: EmergencyRequestsScreen.cardBorderColor,
                    ),
                    _DetailRow(
                      icon: Icons.medical_services_outlined,
                      label: 'Required Units',
                      value: unitsString,
                    ),
                    const Divider(
                      height: 1,
                      indent: 48,
                      color: EmergencyRequestsScreen.cardBorderColor,
                    ),
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Patient Name',
                      value: patientName,
                    ),
                    const Divider(
                      height: 1,
                      indent: 48,
                      color: EmergencyRequestsScreen.cardBorderColor,
                    ),
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Contact Number',
                      value: contactNumber,
                    ),
                    const Divider(
                      height: 1,
                      indent: 48,
                      color: EmergencyRequestsScreen.cardBorderColor,
                    ),
                    _DetailRow(
                      icon: Icons.timelapse_rounded,
                      label: 'Request Status',
                      value: statusDisplay,
                      valueColor: const Color(0xFF2E7D32),
                    ),
                    const Divider(
                      height: 1,
                      indent: 48,
                      color: EmergencyRequestsScreen.cardBorderColor,
                    ),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Created Date & Time',
                      value: createdDateStr,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Description Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: EmergencyRequestsScreen.cardBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: EmergencyRequestsScreen.textSecondaryColor,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Description / Clinical Notes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: EmergencyRequestsScreen.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: EmergencyRequestsScreen.textPrimaryColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Close Details Button (strictly no respond/accept buttons in this step)
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: EmergencyRequestsScreen.cardBorderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: EmergencyRequestsScreen.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper row for displaying key-value information in the details sheet.
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? const Color(0xFF1F2937),
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
