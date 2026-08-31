import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'tabs/donor_search_tab.dart';
import 'pdf_report.dart';
import '../../models/blood_request.dart';
import '../../services/request_service.dart';
import '../../utils/request_status.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_states.dart';
import '../../widgets/request_health_badge.dart';
import '../../widgets/request_timeline.dart';
import '../../widgets/entrance_fade_slide.dart';

/// Full detail view for a single emergency blood request - the
/// "Emergency Blood Request Verification & Donor Coordination"
/// control surface for this request.
///
/// Combines:
///   FR08 - verification workflow (duplicate check, checklist, verify/reject)
///   FR09 - "Find Matching Donors" search launcher
///   FR10 - multi-donor response tracking + unit coordination
/// plus the timeline, audit trail, pinning, and PDF report added in
/// the second iteration of this module. All writes go through
/// [RequestService] rather than touching Firestore directly here.
class RequestDetailsScreen extends StatefulWidget {
  final String requestId;
  const RequestDetailsScreen({super.key, required this.requestId});

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  final Map<String, bool> _checklist = {
    'Patient details are complete': false,
    'Blood group & units are valid': false,
    'Hospital/location confirmed': false,
  };
  bool _duplicateCheckDone = false;
  bool get _checklistComplete => _checklist.values.every((v) => v);

  final _service = RequestService.instance;
  DocumentReference<Map<String, dynamic>> get _requestRef => _service.requestRef(widget.requestId);

  String get _doctorId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _doctorName => FirebaseAuth.instance.currentUser?.email ?? 'Hospital Staff';

  Future<void> _runDuplicateCheck(BloodRequest request) async {
    if (_duplicateCheckDone || request.status != RequestStatus.pending) return;
    _duplicateCheckDone = true;
    try {
      final duplicates = await _service.findPossibleDuplicates(request);
      if (duplicates.isNotEmpty && mounted) {
        _showDuplicateDialog(duplicates);
      }
    } catch (_) {
      // Duplicate detection is a heads-up only (e.g. it needs a
      // Firestore composite index the first time it runs) - a
      // failure here must never block the doctor from verifying.
    }
  }

  /// Runs a Firestore-writing [action] and shows a friendly error
  /// snackbar instead of letting an unhandled Future exception (lost
  /// network, permission-denied, etc.) crash silently in the console.
  Future<void> _safeRun(Future<void> Function() action, {String? errorMessage}) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError ? e.message : (errorMessage ?? 'That action could not be completed. Please try again.');
      showErrorSnack(context, message);
    }
  }

  void _showDuplicateDialog(List<BloodRequest> duplicates) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Possible Duplicate Detected'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Possible duplicate request detected. This request shares the same hospital and blood group as another active request created around the same time. This is not a confirmed duplicate - please review before proceeding.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 12),
              ...duplicates.take(3).map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${d.patientName} — ${d.bloodGroup} — ${RequestStatus.label(d.status)}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Verification'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.critical, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: duplicates.first.id)));
            },
            child: const Text('View Existing Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDonorSearch(BloodRequest request) async {
    final colors = context.colors;
    final donor = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Find Matching Donors'), backgroundColor: colors.surface, foregroundColor: colors.textPrimary),
          body: DonorSearchTab(selectMode: true, initialBloodGroupFilter: request.bloodGroup, requestLocation: request.location),
        ),
      ),
    );
    if (donor == null || !mounted) return;

    final units = await _promptUnitsPledged(request.unitsRemaining == 0 ? request.unitsNeeded : request.unitsRemaining);
    if (units == null || !mounted) return;

    try {
      await _service.notifyDonor(requestId: request.id, donor: donor, unitsPledged: units, doctorId: _doctorId, doctorName: _doctorName);
      if (mounted) showSuccessSnack(context, '${donor['donorName']} notified.');
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError ? e.message : 'Could not notify this donor. Please try again.';
      showErrorSnack(context, message);
    }
  }

  Future<int?> _promptUnitsPledged(int maxUnits) {
    final colors = context.colors;
    final safeMax = maxUnits < 1 ? 1 : maxUnits;
    int value = 1;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Units This Donor Will Provide'),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(onPressed: value > 1 ? () => setDialogState(() => value--) : null, icon: const Icon(Icons.remove_circle_outline)),
              Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: value < safeMax ? () => setDialogState(() => value++) : null, icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, value),
              child: const Text('Notify Donor'),
            ),
          ],
        ),
      ),
    );
  }

  // #validation - a rejection with no real reason recorded breaks the
  // audit trail (a caregiver/hospital has no way to know what to fix
  // and resubmit) so this is now a real Form with a validator instead
  // of accepting whatever text.length happens to be, including empty.
  void _showRejectDialog(BloodRequest request) {
    final colors = context.colors;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Reason for rejection', hintText: 'e.g. Incomplete patient details', border: OutlineInputBorder()),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'A reason is required before rejecting a request.';
              if (v.length < 10) return 'Please provide a more specific reason (at least 10 characters).';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.critical, foregroundColor: Colors.white),
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final reason = controller.text.trim();
              Navigator.pop(context);
              _safeRun(() => _service.rejectRequest(request, doctorId: _doctorId, doctorName: _doctorName, reason: reason));
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Request Details'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _requestRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
              final request = BloodRequest.fromDoc(snapshot.data!);
              final isPinned = request.isPinnedBy(_doctorId);
              return IconButton(
                tooltip: isPinned ? 'Unpin' : 'Pin as important',
                icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                onPressed: () => _safeRun(() => _service.togglePin(request.id, _doctorId, !isPinned)),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _requestRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorStateView(message: 'Unable to load this request right now.\n${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const LoadingState();
          }
          if (!snapshot.data!.exists) {
            return const EmptyState(icon: Icons.search_off_rounded, title: 'Not found', message: 'This request no longer exists.');
          }

          final request = BloodRequest.fromDoc(snapshot.data!);
          _runDuplicateCheck(request);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _requestRef.collection('responses').orderBy('notifiedAt', descending: true).snapshots(),
            builder: (context, responseSnap) {
              // Donor responses are non-critical to the rest of this
              // screen rendering - degrade to an empty list rather
              // than blocking the whole page on a transient error.
              final responses = responseSnap.hasError
                  ? const <DonorResponseRecord>[]
                  : (responseSnap.data?.docs ?? []).map(DonorResponseRecord.fromDoc).toList();

              var delayStep = 0;
              Widget staggered(Widget child) {
                final w = EntranceFadeSlide(delay: Duration(milliseconds: 50 * delayStep), child: child);
                delayStep++;
                return w;
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  staggered(_PatientCaseSummaryCard(request: request)),
                  if (request.status == RequestStatus.pending) ...[
                    const SizedBox(height: 16),
                    staggered(_ChecklistCard(checklist: _checklist, onChanged: (key, value) => setState(() => _checklist[key] = value))),
                    const SizedBox(height: 16),
                    staggered(_VerifyActionsBar(
                      enabled: _checklistComplete,
                      request: request,
                      currentDoctorId: _doctorId,
                      onVerify: () => _safeRun(() => _service.verifyRequest(request, doctorId: _doctorId, doctorName: _doctorName)),
                      onReject: () => _showRejectDialog(request),
                    )),
                  ],
                  if (request.status == RequestStatus.rejected) ...[
                    const SizedBox(height: 16),
                    staggered(_ReVerificationCard(
                      request: request,
                      onRequestReVerification: () =>
                          _safeRun(() => _service.requestReVerification(request, doctorId: _doctorId, doctorName: _doctorName)),
                    )),
                  ],
                  if (request.status == RequestStatus.verified) ...[
                    const SizedBox(height: 16),
                    staggered(_FindDonorsButton(onPressed: () => _openDonorSearch(request))),
                  ],
                  if (request.status == RequestStatus.matched || request.status == RequestStatus.fulfilled) ...[
                    const SizedBox(height: 16),
                    staggered(_CoordinationCard(
                      request: request,
                      responses: responses,
                      onFindMore: () => _openDonorSearch(request),
                      onUpdateStatus: (responseId, donorId, donorName, status) => _safeRun(() => _service.updateResponseStatus(
                        requestId: request.id,
                        responseId: responseId,
                        donorId: donorId,
                        donorName: donorName,
                        status: status,
                        doctorId: _doctorId,
                        doctorName: _doctorName,
                      )),
                    )),
                  ],
                  const SizedBox(height: 16),
                  staggered(_TimelineCard(request: request, responses: responses)),
                  const SizedBox(height: 16),
                  staggered(_AuditTrailCard(requestId: request.id)),
                  const SizedBox(height: 16),
                  staggered(_PdfReportButton(request: request, responses: responses)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Patient Case Summary - the single source of truth the Doctor sees
/// when opening a request. Reads only fields that already exist on the
/// shared `requests` document (see `BloodRequest.fromDoc`); nothing
/// here is invented. Fields the current schema does not track (Age,
/// Gender, Ward, a distinct Required Date/Time) are shown as
/// "Not provided" instead of being fabricated - the Recipient module
/// owns request creation and this screen never writes patient data.
///
/// Visual hierarchy: identity header -> PATIENT INFORMATION ->
/// BLOOD REQUIREMENT -> REQUEST INFORMATION.
class _PatientCaseSummaryCard extends StatelessWidget {
  final BloodRequest request;
  const _PatientCaseSummaryCard({required this.request});

  static const _notProvided = 'Not provided';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = RequestStatus.color(request.status);
    final createdAtLabel = request.createdAt == null
        ? _notProvided
        : '${request.createdAt!.day.toString().padLeft(2, '0')}/${request.createdAt!.month.toString().padLeft(2, '0')}/${request.createdAt!.year}  ${request.createdAt!.hour.toString().padLeft(2, '0')}:${request.createdAt!.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identity header - who this case is about, at a glance.
          Row(
            children: [
              // #hero - continues the same blood-group avatar that was
              // tapped on the Dashboard/Verify/History card, instead of
              // a hard cut to a new screen.
              Hero(
                tag: 'bloodgroup-avatar-${request.id}',
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.critical.withValues(alpha: 0.1),
                  child: Text(request.bloodGroup, style: TextStyle(color: colors.critical, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.patientName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(RequestStatus.icon(request.status), size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(RequestStatus.label(request.status), style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RequestHealthBadge(request: request),

          const SizedBox(height: 16),
          _SectionLabel('PATIENT INFORMATION'),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.badge_outlined, label: 'Patient ID', value: request.id),
          _InfoRow(icon: Icons.person_outline_rounded, label: 'Patient Name', value: request.patientName),
          _InfoRow(icon: Icons.cake_outlined, label: 'Age', value: _notProvided),
          _InfoRow(icon: Icons.wc_rounded, label: 'Gender', value: _notProvided),

          Divider(height: 26, color: colors.border),
          _SectionLabel('BLOOD REQUIREMENT'),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.opacity_rounded, label: 'Blood Group', value: request.bloodGroup),
          _InfoRow(icon: Icons.numbers_rounded, label: 'Units Required', value: '${request.unitsConfirmed}/${request.unitsNeeded} confirmed · ${request.unitsRemaining} remaining'),
          _InfoRow(icon: Icons.priority_high_rounded, label: 'Urgency', value: request.urgency, valueColor: UrgencyLevel.color(request.urgency)),

          Divider(height: 26, color: colors.border),
          _SectionLabel('REQUEST INFORMATION'),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.local_hospital_outlined, label: 'Hospital', value: request.hospitalName),
          _InfoRow(icon: Icons.meeting_room_outlined, label: 'Ward', value: _notProvided),
          _InfoRow(icon: Icons.place_outlined, label: 'Location', value: request.location),
          _InfoRow(icon: Icons.event_outlined, label: 'Required Date/Time', value: _notProvided),
          _InfoRow(icon: Icons.person_pin_outlined, label: 'Requested By', value: request.createdByName),
          if (request.notes.isNotEmpty) _InfoRow(icon: Icons.notes_rounded, label: 'Request Notes', value: request.notes),
          _InfoRow(icon: Icons.schedule_outlined, label: 'Request Created', value: createdAtLabel),
          if (request.verifiedBy != null) _InfoRow(icon: Icons.verified_rounded, label: 'Verified By', value: request.verifiedBy!),
          if (request.rejectionReason != null)
            _InfoRow(icon: Icons.report_outlined, label: 'Rejection Reason', value: request.rejectionReason!, valueColor: colors.critical),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: colors.textSecondary),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: colors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, color: colors.textSecondary))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? colors.textPrimary))),
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final Map<String, bool> checklist;
  final void Function(String, bool) onChanged;
  const _ChecklistCard({required this.checklist, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verification Checklist', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 4),
          Text('Confirm each item before verifying this request.', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          ...checklist.keys.map((key) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: checklist[key],
                onChanged: (v) => onChanged(key, v ?? false),
                activeColor: colors.primary,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(key, style: TextStyle(fontSize: 13, color: colors.textPrimary)),
              )),
        ],
      ),
    );
  }
}

/// #two-person-verification - for a Critical request, the first tap of
/// "Verify Request" only records that staff member's co-sign (status
/// stays pending); a genuinely different staff member has to tap it a
/// second time to actually move the request to `verified`. The same
/// doctor cannot approve their own first co-sign. Every other urgency
/// level keeps the original single-tap flow.
class _VerifyActionsBar extends StatelessWidget {
  final bool enabled;
  final BloodRequest request;
  final String currentDoctorId;
  final VoidCallback onVerify;
  final VoidCallback onReject;
  const _VerifyActionsBar({required this.enabled, required this.request, required this.currentDoctorId, required this.onVerify, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final awaitingSecond = request.awaitingSecondApproval;
    final isSelfApprover = awaitingSecond && request.firstApproverId == currentDoctorId;
    final canVerifyNow = enabled && !isSelfApprover;

    final String verifyLabel;
    if (awaitingSecond) {
      verifyLabel = isSelfApprover ? 'Waiting for 2nd staff member' : 'Confirm 2nd Approval & Verify';
    } else if (request.urgency == 'Critical') {
      verifyLabel = 'Give 1st Approval';
    } else {
      verifyLabel = 'Verify Request';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (awaitingSecond)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: colors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: colors.warning.withValues(alpha: 0.3))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gpp_maybe_outlined, size: 16, color: colors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSelfApprover
                        ? 'You gave the first approval on this critical request. A different staff member must confirm before it is verified.'
                        : '${request.firstApproverName ?? 'A staff member'} gave the first approval. Confirming below records your name as the second, independent approver.',
                    style: TextStyle(fontSize: 12, color: colors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                icon: Icon(Icons.close_rounded, color: colors.critical),
                label: Text('Reject', style: TextStyle(color: colors.critical)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: colors.critical), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: canVerifyNow ? onVerify : null,
                icon: Icon(awaitingSecond ? Icons.how_to_reg_rounded : Icons.verified_rounded),
                label: Text(verifyLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: colors.border,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// #10 - Re-verification workflow entry point for a rejected request.
class _ReVerificationCard extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback onRequestReVerification;
  const _ReVerificationCard({required this.request, required this.onRequestReVerification});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rejected Request', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 6),
          Text('If the recipient has updated this request with corrected information, you can send it back into the verification queue.',
              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRequestReVerification,
              icon: Icon(Icons.replay_rounded, color: colors.primary),
              label: Text('Send for Re-verification', style: TextStyle(color: colors.primary)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: colors.primary), padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FindDonorsButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _FindDonorsButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.search_rounded),
        label: const Text('Find Matching Donors'),
        style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }
}

/// #6/#7 - Donor response rate + multi-donor unit coordination.
class _CoordinationCard extends StatelessWidget {
  final BloodRequest request;
  final List<DonorResponseRecord> responses;
  final VoidCallback onFindMore;
  final Future<void> Function(String responseId, String donorId, String donorName, String status) onUpdateStatus;

  const _CoordinationCard({required this.request, required this.responses, required this.onFindMore, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final notified = responses.length;
    final responded = responses.where((r) => r.status != 'notified').length;
    final responseRate = notified == 0 ? null : (responded / notified * 100).round();
    final progress = request.unitsNeeded == 0 ? 0.0 : (request.unitsConfirmed / request.unitsNeeded).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Donor Coordination', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary))),
              if (request.status != RequestStatus.fulfilled)
                TextButton.icon(
                  onPressed: onFindMore,
                  icon: Icon(Icons.add_rounded, size: 18, color: colors.primary),
                  label: Text('Notify More', style: TextStyle(color: colors.primary, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${request.unitsConfirmed} / ${request.unitsNeeded} Units Confirmed', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary)),
              const Spacer(),
              if (request.unitsRemaining > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: colors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text('${request.unitsRemaining} unit(s) remaining', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: colors.warning)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: colors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 11, color: colors.success),
                      const SizedBox(width: 3),
                      Text('Fully covered', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: colors.success)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) =>
                  LinearProgressIndicator(value: value, minHeight: 10, backgroundColor: colors.elevatedSurface, valueColor: AlwaysStoppedAnimation(colors.primary)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            notified == 0 ? 'No donors notified yet.' : '$notified notified · $responded responded · ${responseRate ?? 0}% response rate',
            style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
          ),
          Divider(height: 24, color: colors.border),
          if (responses.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('No donors notified yet.', style: TextStyle(fontSize: 13, color: colors.textSecondary)))
          else
            ...responses.map((r) => _ResponseRow(response: r, onUpdateStatus: onUpdateStatus)),
        ],
      ),
    );
  }
}

class _ResponseRow extends StatelessWidget {
  final DonorResponseRecord response;
  final Future<void> Function(String responseId, String donorId, String donorName, String status) onUpdateStatus;
  const _ResponseRow({required this.response, required this.onUpdateStatus});

  Color _statusColor(AppColors colors) {
    switch (response.status) {
      case 'accepted':
        return colors.primary;
      case 'declined':
        return colors.critical;
      case 'completed':
        return colors.success;
      default:
        return colors.warning;
    }
  }

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = _statusColor(colors);
    final declined = response.status == 'declined';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: declined ? colors.critical.withValues(alpha: 0.04) : colors.elevatedSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: declined ? colors.critical.withValues(alpha: 0.25) : colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 18, backgroundColor: statusColor.withValues(alpha: 0.12), child: Icon(Icons.person_rounded, size: 18, color: statusColor)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(response.donorName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                    Text(
                      response.status == 'completed' ? '${response.unitsPledged} unit(s) confirmed' : '${response.unitsPledged} unit(s) pledged',
                      style: TextStyle(fontSize: 11, color: response.status == 'completed' ? colors.success : colors.textSecondary, fontWeight: response.status == 'completed' ? FontWeight.w600 : FontWeight.normal),
                    ),
                  ],
                ),
              ),
              if (response.status == 'notified')
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: colors.textSecondary),
                  onSelected: (value) => onUpdateStatus(response.id, response.donorId, response.donorName, value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'accepted', child: Text('Mark Accepted')),
                    PopupMenuItem(value: 'declined', child: Text('Mark Declined')),
                  ],
                ),
              if (response.status == 'accepted')
                TextButton(
                  onPressed: () => onUpdateStatus(response.id, response.donorId, response.donorName, 'completed'),
                  child: Text('Mark Completed', style: TextStyle(color: colors.primary, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // #7 - a real progress tracker built only from the fields
          // this response actually has (notifiedAt / respondedAt /
          // status) - no invented "viewed" stage, since that isn't
          // tracked anywhere in Firestore yet.
          _ResponseStageTracker(response: response),
        ],
      ),
    );
  }
}

/// #7 - Donor Response Tracking mini-funnel for a single donor:
/// Notified -> Responded (Accepted/Declined) -> Completed, each dot
/// timestamped from the real `notifiedAt`/`respondedAt` fields.
class _ResponseStageTracker extends StatelessWidget {
  final DonorResponseRecord response;
  const _ResponseStageTracker({required this.response});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final declined = response.status == 'declined';
    final reachedResponded = response.status != 'notified';
    final reachedCompleted = response.status == 'completed';
    final lineColor = declined ? colors.critical : colors.success;

    final stages = [
      ('Notified', true, response.notifiedAt),
      (declined ? 'Declined' : 'Responded', reachedResponded, response.respondedAt),
      ('Completed', reachedCompleted, reachedCompleted ? response.respondedAt : null),
    ];

    return Row(
      children: [
        for (int i = 0; i < stages.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: stages[i].$2 ? lineColor.withValues(alpha: 0.5) : colors.border,
              ),
            ),
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stages[i].$2 ? (declined && i > 0 ? colors.critical : lineColor) : colors.border,
                ),
              ),
              const SizedBox(height: 4),
              Text(stages[i].$1, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: stages[i].$2 ? colors.textPrimary : colors.textSecondary)),
              if (stages[i].$3 != null)
                Text(_ResponseRow._formatTime(stages[i].$3), style: TextStyle(fontSize: 9, color: colors.textSecondary)),
            ],
          ),
        ],
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final BloodRequest request;
  final List<DonorResponseRecord> responses;
  const _TimelineCard({required this.request, required this.responses});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Request Timeline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 12),
          RequestTimeline(request: request, responses: responses),
        ],
      ),
    );
  }
}

class _AuditTrailCard extends StatefulWidget {
  final String requestId;
  const _AuditTrailCard({required this.requestId});

  @override
  State<_AuditTrailCard> createState() => _AuditTrailCardState();
}

class _AuditTrailCardState extends State<_AuditTrailCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Expanded(child: Text('Audit Trail', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary))),
                Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: colors.textSecondary),
              ],
            ),
          ),
          if (_expanded)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: RequestService.instance.auditTrail(widget.requestId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Audit trail is temporarily unavailable.', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LoadingState());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('No audit entries yet.', style: TextStyle(fontSize: 12, color: colors.textSecondary)));
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final ts = (data['timestamp'] as Timestamp?)?.toDate();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.circle, size: 6, color: colors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_actionLabel(data['action'] as String? ?? '')} — ${data['performedByName'] ?? ''}${ts != null ? ' (${_fmt(ts)})' : ''}',
                                style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  static String _actionLabel(String action) => action.replaceAll('_', ' ');

  static String _fmt(DateTime dt) {
    final l = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}, ${l.day}/${l.month}';
  }
}

class _PdfReportButton extends StatelessWidget {
  final BloodRequest request;
  final List<DonorResponseRecord> responses;
  const _PdfReportButton({required this.request, required this.responses});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          List<Map<String, dynamic>> entries = const [];
          try {
            final auditSnap = await RequestService.instance.auditTrail(request.id).first;
            entries = auditSnap.docs.map((doc) {
              final data = doc.data();
              final ts = (data['timestamp'] as Timestamp?)?.toDate();
              return {
                'action': (data['action'] as String? ?? '').replaceAll('_', ' '),
                'performedByName': data['performedByName'],
                'timestampLabel': ts == null ? '' : '${ts.toLocal()}'.split('.').first,
              };
            }).toList();
          } catch (_) {
            // Report generation should still proceed with an empty
            // audit section rather than failing outright.
          }

          if (context.mounted) {
            await generateRequestReport(context: context, request: request, responses: responses, auditEntries: entries);
          }
        },
        icon: Icon(Icons.picture_as_pdf_outlined, color: colors.primary),
        label: Text('Generate PDF Report', style: TextStyle(color: colors.primary)),
        style: OutlinedButton.styleFrom(side: BorderSide(color: colors.primary), padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    );
  }
}
