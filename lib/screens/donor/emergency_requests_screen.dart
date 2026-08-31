import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Screen displaying active emergency blood requests from Firestore `blood_requests`.
class EmergencyRequestsScreen extends StatelessWidget {
  const EmergencyRequestsScreen({super.key});

  static const Color primaryColor = Color(0xFFC62828); // Deep Crimson Red
  static const Color surfaceColor = Color(0xFFF9FAFB);
  static const Color cardBorderColor = Color(0xFFE5E7EB);
  static const Color textPrimaryColor = Color(0xFF1F2937);
  static const Color textSecondaryColor = Color(0xFF6B7280);

  /// Formats date string from Timestamp, DateTime, or String safely.
  static String formatRequestDate(dynamic value) {
    if (value == null) return 'Date not specified';

    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) return 'Date not specified';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final monthStr = months[date.month - 1];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')} $monthStr ${date.year} at $hour:$minute';
  }

  /// Converts dynamic timestamp to DateTime for client-side sorting.
  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Checks whether request status is active/open/pending.
  static bool _isActiveStatus(dynamic rawStatus) {
    if (rawStatus == null) return true; // Include unlabelled requests as active by default
    final status = rawStatus.toString().trim().toLowerCase();
    const inactiveStatuses = ['completed', 'cancelled', 'canceled', 'closed', 'fulfilled'];
    if (inactiveStatuses.contains(status)) return false;
    return true;
  }

  /// Returns visual configuration (label, foreground, background, icon) for an urgency level.
  static _UrgencyBadgeConfig _getUrgencyConfig(dynamic rawUrgency) {
    final urgency = rawUrgency?.toString().trim().toLowerCase() ?? '';

    switch (urgency) {
      case 'critical':
        return const _UrgencyBadgeConfig(
          label: 'Critical',
          textColor: Color(0xFF991B1B),
          backgroundColor: Color(0xFFFEE2E2),
          borderColor: Color(0xFFFCA5A5),
          icon: Icons.warning_amber_rounded,
        );
      case 'high':
        return const _UrgencyBadgeConfig(
          label: 'High Urgency',
          textColor: Color(0xFFC2410C),
          backgroundColor: Color(0xFFFFEDD5),
          borderColor: Color(0xFFFDBA74),
          icon: Icons.priority_high_rounded,
        );
      case 'medium':
        return const _UrgencyBadgeConfig(
          label: 'Medium Urgency',
          textColor: Color(0xFFB45309),
          backgroundColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFFDE68A),
          icon: Icons.info_outline_rounded,
        );
      case 'low':
        return const _UrgencyBadgeConfig(
          label: 'Low Urgency',
          textColor: Color(0xFF15803D),
          backgroundColor: Color(0xFFDCFCE7),
          borderColor: Color(0xFF86EFAC),
          icon: Icons.check_circle_outline_rounded,
        );
      default:
        final displayLabel = rawUrgency != null && rawUrgency.toString().trim().isNotEmpty
            ? rawUrgency.toString().trim()
            : 'Standard';
        return _UrgencyBadgeConfig(
          label: displayLabel,
          textColor: const Color(0xFF4B5563),
          backgroundColor: const Color(0xFFF3F4F6),
          borderColor: const Color(0xFFE5E7EB),
          icon: Icons.info_outline_rounded,
        );
    }
  }

  void _showRequestDetails(BuildContext context, Map<String, dynamic> data, String requestId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RequestDetailsBottomSheet(data: data, requestId: requestId),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _getRequestsStream() {
    try {
      return FirebaseFirestore.instance
          .collection('blood_requests')
          .snapshots();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _getRequestsStream();

    if (stream == null) {
      return Scaffold(
        backgroundColor: surfaceColor,
        appBar: AppBar(
          title: const Text(
            'Emergency Requests',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: const Center(
          child: Text(
            'Database is not connected.',
            style: TextStyle(color: textSecondaryColor, fontSize: 14),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: const Text(
          'Emergency Requests',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          // Loading state
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
                    'Searching for emergency blood requests...',
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondaryColor,
                    ),
                  ),
                ],
              ),
            );
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Color(0xFFD32F2F),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load emergency requests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error?.toString() ?? 'An error occurred.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Filter for active/open requests only
          final activeDocs = allDocs.where((doc) {
            final data = doc.data();
            return _isActiveStatus(data['status']);
          }).toList();

          // Sort by createdAt descending
          activeDocs.sort((a, b) {
            final dateA = _parseDateTime(a.data()['createdAt']);
            final dateB = _parseDateTime(b.data()['createdAt']);
            return dateB.compareTo(dateA);
          });

          // Empty state
          if (activeDocs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 56,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Emergency Requests',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'There are currently no active emergency blood requests. Check back later or ensure your availability status is turned on.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondaryColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // List of emergency request cards
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
            itemCount: activeDocs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = activeDocs[index];
              final data = doc.data();
              final requestId = doc.id;

              final bloodGroup = (data['bloodGroup'] as String?)?.trim().isNotEmpty == true
                  ? (data['bloodGroup'] as String).trim()
                  : 'Not specified';

              final hospitalName = (data['hospitalName'] as String?)?.trim().isNotEmpty == true
                  ? (data['hospitalName'] as String).trim()
                  : 'Unknown hospital';

              final location = (data['location'] as String?)?.trim().isNotEmpty == true
                  ? (data['location'] as String).trim()
                  : 'Unknown location';

              final urgencyConfig = _getUrgencyConfig(data['urgency']);

              final rawUnits = data['requiredUnits'];
              final unitsString = rawUnits != null
                  ? '$rawUnits ${rawUnits == 1 ? 'Unit' : 'Units'} required'
                  : 'Units: Not specified';

              final statusRaw = (data['status'] as String?)?.trim();
              final statusDisplay = (statusRaw != null && statusRaw.isNotEmpty)
                  ? statusRaw[0].toUpperCase() + statusRaw.substring(1).toLowerCase()
                  : 'Active';

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: cardBorderColor),
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
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(10),
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
                              color: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hospitalName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Location & Units info
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: textSecondaryColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                location,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Row(
                          children: [
                            const Icon(
                              Icons.medical_services_outlined,
                              size: 16,
                              color: textSecondaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              unitsString,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textPrimaryColor,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // Footer: Status + View Details Tap Hint
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
                              children: [
                                Text(
                                  'View Details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: primaryColor,
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
    );
  }
}

/// Helper model holding UI colors and icon for an urgency level.
class _UrgencyBadgeConfig {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;

  const _UrgencyBadgeConfig({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
  });
}

/// Modal Bottom Sheet displaying in-depth information about a specific blood request.
class _RequestDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final String requestId;

  const _RequestDetailsBottomSheet({
    required this.data,
    required this.requestId,
  });

  static const Color primaryColor = Color(0xFFC62828);
  static const Color textPrimaryColor = Color(0xFF1F2937);
  static const Color textSecondaryColor = Color(0xFF6B7280);
  static const Color cardBorderColor = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final bloodGroup = (data['bloodGroup'] as String?)?.trim().isNotEmpty == true
        ? (data['bloodGroup'] as String).trim()
        : 'Not specified';

    final hospitalName = (data['hospitalName'] as String?)?.trim().isNotEmpty == true
        ? (data['hospitalName'] as String).trim()
        : 'Unknown hospital';

    final location = (data['location'] as String?)?.trim().isNotEmpty == true
        ? (data['location'] as String).trim()
        : 'Unknown location';

    final rawUnits = data['requiredUnits'];
    final unitsString = rawUnits != null
        ? '$rawUnits ${rawUnits == 1 ? 'Unit' : 'Units'}'
        : 'Not specified';

    final patientName = (data['patientName'] as String?)?.trim().isNotEmpty == true
        ? (data['patientName'] as String).trim()
        : 'Not specified';

    final contactNumber = (data['contactNumber'] as String?)?.trim().isNotEmpty == true
        ? (data['contactNumber'] as String).trim()
        : 'Not specified';

    final description = (data['description'] as String?)?.trim().isNotEmpty == true
        ? (data['description'] as String).trim()
        : 'No additional clinical description provided.';

    final rawStatus = (data['status'] as String?)?.trim();
    final statusDisplay = (rawStatus != null && rawStatus.isNotEmpty)
        ? rawStatus[0].toUpperCase() + rawStatus.substring(1).toLowerCase()
        : 'Active';

    final urgencyConfig = EmergencyRequestsScreen._getUrgencyConfig(data['urgency']);
    final createdDateStr = EmergencyRequestsScreen.formatRequestDate(data['createdAt']);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 48),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset + 24),
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
              // Drag handle
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

              // Title and Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Request Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Blood Group & Urgency Banner Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(14),
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
                              color: textPrimaryColor,
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

              const SizedBox(height: 20),

              // Detail List Items
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorderColor),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: location,
                    ),
                    const Divider(height: 1, indent: 48),
                    _DetailRow(
                      icon: Icons.medical_services_outlined,
                      label: 'Required Units',
                      value: unitsString,
                    ),
                    const Divider(height: 1, indent: 48),
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Patient Name',
                      value: patientName,
                    ),
                    const Divider(height: 1, indent: 48),
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Contact Number',
                      value: contactNumber,
                    ),
                    const Divider(height: 1, indent: 48),
                    _DetailRow(
                      icon: Icons.timelapse_rounded,
                      label: 'Status',
                      value: statusDisplay,
                      valueColor: const Color(0xFF2E7D32),
                    ),
                    const Divider(height: 1, indent: 48),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Created Date',
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
                  border: Border.all(color: cardBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: textSecondaryColor,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Description / Clinical Notes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: textPrimaryColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Close button
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper tile for detailed attribute display inside request bottom sheet.
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
