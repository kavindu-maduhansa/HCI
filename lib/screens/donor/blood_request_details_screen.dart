import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Screen displaying the full details of a blood request, allowing a donor
/// to submit a response ("I Can Donate") while preventing duplicate responses.
class BloodRequestDetailsScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const BloodRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  static const Color primaryColor = Color(0xFFC62828); // Deep Crimson Red
  static const Color surfaceColor = Color(0xFFF9FAFB);
  static const Color cardBorderColor = Color(0xFFE5E7EB);
  static const Color textPrimaryColor = Color(0xFF1F2937);
  static const Color textSecondaryColor = Color(0xFF6B7280);

  /// Helper to safely format timestamp or date string.
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

  /// Returns visual configuration for an urgency level.
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
  State<BloodRequestDetailsScreen> createState() => _BloodRequestDetailsScreenState();
}

class _BloodRequestDetailsScreenState extends State<BloodRequestDetailsScreen> {
  bool _isCheckingResponse = true;
  bool _hasAlreadyResponded = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkExistingResponse();
  }

  /// Checks Firestore `donor_responses` to verify if current donor already responded.
  Future<void> _checkExistingResponse() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isCheckingResponse = false);
        return;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('donor_responses')
          .where('requestId', isEqualTo: widget.requestId)
          .where('donorId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _hasAlreadyResponded = querySnapshot.docs.isNotEmpty;
          _isCheckingResponse = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingResponse = false);
      }
    }
  }

  /// Handles "I Can Donate" response submission.
  Future<void> _handleDonateResponse() async {
    if (_hasAlreadyResponded || _isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to respond to blood requests.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Step 1: Check duplicate response before writing
      final existingResponse = await FirebaseFirestore.instance
          .collection('donor_responses')
          .where('requestId', isEqualTo: widget.requestId)
          .where('donorId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (existingResponse.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _hasAlreadyResponded = true;
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already responded to this blood request.'),
              backgroundColor: Color(0xFFF57F17),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Step 2: Fetch current donor profile from users/{uid}
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      final rawFullName = userData['fullName'] as String?;
      final donorName = (rawFullName != null && rawFullName.trim().isNotEmpty)
          ? rawFullName.trim()
          : (user.displayName != null && user.displayName!.trim().isNotEmpty)
              ? user.displayName!.trim()
              : 'Anonymous Donor';

      final rawBloodGroup = userData['bloodGroup'] as String?;
      final donorBloodGroup = (rawBloodGroup != null && rawBloodGroup.trim().isNotEmpty)
          ? rawBloodGroup.trim()
          : 'Not specified';

      final rawPhone = userData['phoneNumber'] as String?;
      final donorPhone = (rawPhone != null && rawPhone.trim().isNotEmpty)
          ? rawPhone.trim()
          : 'Not specified';

      final rawEmail = userData['email'] as String?;
      final donorEmail = (rawEmail != null && rawEmail.trim().isNotEmpty)
          ? rawEmail.trim()
          : (user.email != null && user.email!.trim().isNotEmpty)
              ? user.email!.trim()
              : 'Not specified';

      // Step 3: Save donor response to donor_responses collection
      final requestHospital = (widget.requestData['hospitalName'] as String?)?.trim() ?? 'Unknown Hospital';
      final requestedBloodGroup = (widget.requestData['bloodGroup'] as String?)?.trim() ?? 'Unknown';
      final requestUrgency = (widget.requestData['urgency'] as String?)?.trim() ?? 'Standard';

      await FirebaseFirestore.instance.collection('donor_responses').add({
        'requestId': widget.requestId,
        'donorId': user.uid,
        'donorName': donorName,
        'bloodGroup': donorBloodGroup,
        'phoneNumber': donorPhone,
        'email': donorEmail,
        'status': 'pending',
        'respondedAt': FieldValue.serverTimestamp(),
        'hospitalName': requestHospital,
        'requestBloodGroup': requestedBloodGroup,
        'urgency': requestUrgency,
      });

      if (mounted) {
        setState(() {
          _hasAlreadyResponded = true;
          _isSubmitting = false;
        });

        // Step 4: Show success confirmation dialog
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit response. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Displays a friendly confirmation dialog after response submission.
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 52,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thank You, Donor!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: BloodRequestDetailsScreen.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Your response has been submitted successfully. The hospital coordinator has been notified and may contact you soon.',
              style: TextStyle(
                fontSize: 14,
                color: BloodRequestDetailsScreen.textSecondaryColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BloodRequestDetailsScreen.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Great, Understood',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.requestData;

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

    final urgencyConfig = BloodRequestDetailsScreen.getUrgencyConfig(data['urgency']);

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
        : 'No additional clinical notes or description provided.';

    final rawStatus = data['status'] as String?;
    final statusDisplay = (rawStatus != null && rawStatus.trim().isNotEmpty)
        ? rawStatus.trim()[0].toUpperCase() + rawStatus.trim().substring(1).toLowerCase()
        : 'Active';

    final createdDateStr = BloodRequestDetailsScreen.formatRequestDate(data['createdAt']);

    return Scaffold(
      backgroundColor: BloodRequestDetailsScreen.surfaceColor,
      appBar: AppBar(
        title: const Text(
          'Emergency Request Details',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: BloodRequestDetailsScreen.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Banner: Blood Group + Hospital + Urgency Badge
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: BloodRequestDetailsScreen.cardBorderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Blood group badge
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFB71C1C),
                                Color(0xFFE53935),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: BloodRequestDetailsScreen.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.water_drop_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bloodGroup,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hospitalName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: BloodRequestDetailsScreen.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
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
                                      size: 13,
                                      color: urgencyConfig.textColor,
                                    ),
                                    const SizedBox(width: 5),
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
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 2. Request Information Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: BloodRequestDetailsScreen.cardBorderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.location_on_outlined,
                          iconColor: const Color(0xFF2563EB),
                          label: 'Hospital Location',
                          value: location,
                        ),
                        const Divider(
                          height: 1,
                          indent: 52,
                          color: BloodRequestDetailsScreen.cardBorderColor,
                        ),
                        _DetailRow(
                          icon: Icons.medical_services_outlined,
                          iconColor: BloodRequestDetailsScreen.primaryColor,
                          label: 'Required Units',
                          value: unitsString,
                        ),
                        const Divider(
                          height: 1,
                          indent: 52,
                          color: BloodRequestDetailsScreen.cardBorderColor,
                        ),
                        _DetailRow(
                          icon: Icons.person_outline_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          label: 'Patient Name',
                          value: patientName,
                        ),
                        const Divider(
                          height: 1,
                          indent: 52,
                          color: BloodRequestDetailsScreen.cardBorderColor,
                        ),
                        _DetailRow(
                          icon: Icons.phone_outlined,
                          iconColor: const Color(0xFF059669),
                          label: 'Contact Number',
                          value: contactNumber,
                        ),
                        const Divider(
                          height: 1,
                          indent: 52,
                          color: BloodRequestDetailsScreen.cardBorderColor,
                        ),
                        _DetailRow(
                          icon: Icons.timelapse_rounded,
                          iconColor: const Color(0xFFD97706),
                          label: 'Request Status',
                          value: statusDisplay,
                          valueColor: const Color(0xFF2E7D32),
                        ),
                        const Divider(
                          height: 1,
                          indent: 52,
                          color: BloodRequestDetailsScreen.cardBorderColor,
                        ),
                        _DetailRow(
                          icon: Icons.calendar_today_outlined,
                          iconColor: const Color(0xFF4B5563),
                          label: 'Request Date & Time',
                          value: createdDateStr,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 3. Clinical Description / Notes Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BloodRequestDetailsScreen.cardBorderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 18,
                              color: BloodRequestDetailsScreen.textSecondaryColor,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Clinical Notes & Instructions',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BloodRequestDetailsScreen.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: BloodRequestDetailsScreen.textPrimaryColor,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 4. Bottom Action Bar with "I Can Donate" Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: BloodRequestDetailsScreen.cardBorderColor),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: _buildActionButton(),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the dynamic bottom response action button according to state.
  Widget _buildActionButton() {
    if (_isCheckingResponse) {
      return SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BloodRequestDetailsScreen.textSecondaryColor,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Checking response status...',
                style: TextStyle(
                  color: BloodRequestDetailsScreen.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasAlreadyResponded) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFA5D6A7)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF2E7D32),
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Response Already Submitted',
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleDonateResponse,
        style: ElevatedButton.styleFrom(
          backgroundColor: BloodRequestDetailsScreen.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: BloodRequestDetailsScreen.primaryColor.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Submitting Response...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.volunteer_activism_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'I Can Donate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Helper model for urgency level styling.
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

/// Helper row for displaying key-value information in details card.
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (iconColor ?? const Color(0xFF6B7280)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: BloodRequestDetailsScreen.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? BloodRequestDetailsScreen.textPrimaryColor,
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
