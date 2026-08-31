import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/blood_request.dart';
import '../utils/request_status.dart';

/// Centralises every Firestore write the Doctor/Hospital module makes,
/// so screens stay presentation-only (item #22 - code architecture).
/// Every action here also writes an entry to `auditLogs` (item #11).
class RequestService {
  RequestService._();
  static final RequestService instance = RequestService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests => _db.collection('requests');
  CollectionReference<Map<String, dynamic>> get _auditLogs => _db.collection('auditLogs');
  CollectionReference<Map<String, dynamic>> get _alerts => _db.collection('alerts');

  DocumentReference<Map<String, dynamic>> requestRef(String requestId) => _requests.doc(requestId);

  // ---------------------------------------------------------------
  // Audit trail (#11)
  // ---------------------------------------------------------------
  Future<void> logAudit({
    required String action,
    required String requestId,
    required String performedBy,
    required String performedByName,
    Map<String, dynamic>? details,
  }) async {
    await _auditLogs.add({
      'action': action,
      'requestId': requestId,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'timestamp': FieldValue.serverTimestamp(),
      'details': ?details,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> auditTrail(String requestId) {
    return _auditLogs
        .where('requestId', isEqualTo: requestId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ---------------------------------------------------------------
  // Duplicate detection (#4) - operational heuristic, not a
  // definitive claim. Looks for other active requests at the same
  // hospital, for the same blood group, created close in time.
  // ---------------------------------------------------------------
  Future<List<BloodRequest>> findPossibleDuplicates(BloodRequest request) async {
    if (request.createdAt == null) return [];
    final snapshot = await _requests
        .where('hospitalName', isEqualTo: request.hospitalName)
        .where('bloodGroup', isEqualTo: request.bloodGroup)
        .where('status', whereIn: RequestStatus.activeStatuses)
        .limit(20)
        .get();

    return snapshot.docs
        .map(BloodRequest.fromDoc)
        .where((r) => r.id != request.id)
        .where((r) {
          if (r.createdAt == null) return false;
          final diff = r.createdAt!.difference(request.createdAt!).abs();
          // Same hospital + same blood group + created within a 24h
          // window is treated as a *possible* duplicate worth a
          // manual look - never asserted as definite.
          return diff.inHours <= 24;
        })
        .toList();
  }

  // ---------------------------------------------------------------
  // FR08 - verification workflow
  // ---------------------------------------------------------------
  // #two-person-verification - Critical urgency requests require a
  // second, different staff member to co-sign before the request
  // actually transitions to `verified`. Every other urgency level
  // keeps the original single-tap flow, unchanged.
  Future<void> verifyRequest(BloodRequest request, {required String doctorId, required String doctorName}) async {
    if (!RequestStatus.isValidTransition(request.status, RequestStatus.verified)) return;

    if (request.urgency == UrgencyLevel.critical) {
      if (request.firstApproverId == null) {
        // First co-sign only - status stays pending until a second,
        // different staff member confirms.
        await requestRef(request.id).update({
          'firstApproverId': doctorId,
          'firstApproverName': doctorName,
          'firstApprovedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await logAudit(
          action: 'request_first_approval',
          requestId: request.id,
          performedBy: doctorId,
          performedByName: doctorName,
          details: {'note': 'Critical request - awaiting a second, independent staff member to co-sign.'},
        );
        return;
      }
      if (request.firstApproverId == doctorId) {
        throw StateError('You already gave the first approval on this critical request. A different staff member must confirm it.');
      }
      await requestRef(request.id).update({
        'status': RequestStatus.verified,
        'verifiedBy': doctorName,
        'verifiedAt': FieldValue.serverTimestamp(),
        'secondApproverId': doctorId,
        'secondApproverName': doctorName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await logAudit(
        action: 'request_verified',
        requestId: request.id,
        performedBy: doctorId,
        performedByName: doctorName,
        details: {'firstApprover': request.firstApproverName, 'secondApprover': doctorName},
      );
      return;
    }

    await requestRef(request.id).update({
      'status': RequestStatus.verified,
      'verifiedBy': doctorName,
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await logAudit(
      action: 'request_verified',
      requestId: request.id,
      performedBy: doctorId,
      performedByName: doctorName,
    );
  }

  Future<void> rejectRequest(
    BloodRequest request, {
    required String doctorId,
    required String doctorName,
    required String reason,
  }) async {
    if (!RequestStatus.isValidTransition(request.status, RequestStatus.rejected)) return;
    await requestRef(request.id).update({
      'status': RequestStatus.rejected,
      'verifiedBy': doctorName,
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });
    await logAudit(
      action: 'request_rejected',
      requestId: request.id,
      performedBy: doctorId,
      performedByName: doctorName,
      details: {'reason': reason},
    );
  }

  /// #10 - Re-verification workflow. Moves a rejected/expired request
  /// back to `pending` so it re-enters the verification queue after
  /// the recipient updates it. Uses the same `requests` collection -
  /// no second request-creation system is introduced.
  Future<void> requestReVerification(
    BloodRequest request, {
    required String doctorId,
    required String doctorName,
  }) async {
    if (!RequestStatus.isValidTransition(request.status, RequestStatus.pending)) return;
    await requestRef(request.id).update({
      'status': RequestStatus.pending,
      'rejectionReason': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await logAudit(
      action: 'reverification_requested',
      requestId: request.id,
      performedBy: doctorId,
      performedByName: doctorName,
    );
  }

  // ---------------------------------------------------------------
  // FR09/FR10 - donor notification + response tracking
  // ---------------------------------------------------------------
  Future<void> notifyDonor({
    required String requestId,
    required Map<String, dynamic> donor,
    required int unitsPledged,
    required String doctorId,
    required String doctorName,
  }) async {
    // Prevent notifying the same donor twice for the same request
    // while they still have an active (non-declined) response on
    // file - a fresh notification is allowed again if they declined.
    final existing = await requestRef(requestId).collection('responses').where('donorId', isEqualTo: donor['donorId']).get();
    final alreadyActive = existing.docs.any((d) => d.data()['status'] != 'declined');
    if (alreadyActive) {
      throw StateError('${donor['donorName']} has already been notified for this request.');
    }

    await requestRef(requestId).collection('responses').add({
      'donorId': donor['donorId'],
      'donorName': donor['donorName'],
      'donorPhone': donor['donorPhone'],
      'bloodGroup': donor['bloodGroup'],
      'status': 'notified',
      'unitsPledged': unitsPledged,
      'notifiedBy': doctorName,
      'notifiedAt': FieldValue.serverTimestamp(),
    });

    await requestRef(requestId).update({
      'status': RequestStatus.matched,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _recomputeCounts(requestId);

    await logAudit(
      action: 'donor_notified',
      requestId: requestId,
      performedBy: doctorId,
      performedByName: doctorName,
      details: {'donorName': donor['donorName']},
    );
  }

  Future<void> updateResponseStatus({
    required String requestId,
    required String responseId,
    required String donorId,
    required String donorName,
    required String status, // accepted, declined, completed
    required String doctorId,
    required String doctorName,
  }) async {
    await requestRef(requestId).collection('responses').doc(responseId).update({
      'status': status,
      'respondedAt': FieldValue.serverTimestamp(),
    });

    if (status == 'completed') {
      await _db.collection('users').doc(donorId).update({
        'lastDonationDate': FieldValue.serverTimestamp(),
      });
    }

    await _recomputeCounts(requestId);
    await _createResponseAlert(requestId: requestId, donorName: donorName, status: status);

    await logAudit(
      action: 'donor_response_$status',
      requestId: requestId,
      performedBy: doctorId,
      performedByName: doctorName,
      details: {'donorName': donorName},
    );
  }

  /// Recomputes the request's denormalised counters
  /// (`unitsConfirmed`, `donorsNotifiedCount`, `donorsAcceptedCount`)
  /// from its `responses` subcollection, and rolls the request's own
  /// status forward/back to reflect fulfilment progress. Kept as a
  /// one-shot read + write (not a listener) to avoid extra realtime
  /// listener overhead per item #19.
  Future<void> _recomputeCounts(String requestId) async {
    final reqSnap = await requestRef(requestId).get();
    final unitsNeeded = (reqSnap.data()?['unitsNeeded'] as num?)?.toInt() ?? 1;
    final currentStatus = reqSnap.data()?['status'] as String? ?? RequestStatus.pending;

    final responses = await requestRef(requestId).collection('responses').get();
    var notified = 0;
    var accepted = 0;
    var confirmedUnits = 0;
    for (final doc in responses.docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? 'notified';
      final units = (data['unitsPledged'] as num?)?.toInt() ?? 1;
      notified++;
      if (status == 'accepted' || status == 'completed') {
        accepted++;
        confirmedUnits += units;
      }
    }

    final update = <String, dynamic>{
      'donorsNotifiedCount': notified,
      'donorsAcceptedCount': accepted,
      'unitsConfirmed': confirmedUnits,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Only move the top-level status forward when it is still an
    // active, non-terminal state, so a rejected/expired request is
    // never silently re-activated by a stray response update (#20).
    if (RequestStatus.activeStatuses.contains(currentStatus)) {
      if (confirmedUnits >= unitsNeeded && unitsNeeded > 0) {
        update['status'] = RequestStatus.fulfilled;
      } else if (accepted == 0 && currentStatus == RequestStatus.matched && notified > 0) {
        // every notified donor declined - back to verified so staff
        // can search again.
        update['status'] = RequestStatus.verified;
      }
    }

    await requestRef(requestId).update(update);
  }

  // ---------------------------------------------------------------
  // #13 - Pin important requests (kept on the request document itself
  // so it is visible to every doctor account, consistent with the
  // rest of this Firestore-backed module).
  // ---------------------------------------------------------------
  Future<void> togglePin(String requestId, String doctorId, bool pin) async {
    await requestRef(requestId).update({
      'pinnedBy': pin ? FieldValue.arrayUnion([doctorId]) : FieldValue.arrayRemove([doctorId]),
    });
  }

  // ---------------------------------------------------------------
  // #8 - Smart Alert Center (Firestore-based, no FCM configured yet)
  // ---------------------------------------------------------------
  Future<void> _createResponseAlert({
    required String requestId,
    required String donorName,
    required String status,
  }) async {
    if (status != 'accepted' && status != 'declined') return;
    final id = '${requestId}_${status}_$donorName'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    await _alerts.doc(id).set({
      'type': status == 'accepted' ? 'donor_accepted' : 'donor_declined',
      'requestId': requestId,
      'message': status == 'accepted' ? '$donorName accepted a donation request.' : '$donorName declined a donation request.',
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': <String>[],
    }, SetOptions(merge: true));
  }

  /// Deterministic alert for a newly-created critical pending request,
  /// so re-running this from multiple doctor devices never creates
  /// duplicate alerts (same doc id is simply overwritten/merged).
  Future<void> createCriticalRequestAlert(BloodRequest request) async {
    await _alerts.doc('critical_${request.id}').set({
      'type': 'critical_request',
      'requestId': request.id,
      'message': 'New CRITICAL request: ${request.bloodGroup} for ${request.patientName} at ${request.hospitalName}.',
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': <String>[],
    }, SetOptions(merge: true));
  }

  Future<void> createPendingVerificationAlert(BloodRequest request) async {
    await _alerts.doc('pending_${request.id}').set({
      'type': 'pending_verification',
      'requestId': request.id,
      'message': 'New request awaiting verification: ${request.bloodGroup} at ${request.hospitalName}.',
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': <String>[],
    }, SetOptions(merge: true));
  }

  Future<void> markAlertRead(String alertId, String doctorId) async {
    await _alerts.doc(alertId).update({
      'readBy': FieldValue.arrayUnion([doctorId]),
    });
  }

  /// #23 - "mark all read". Batches the update so marking a large
  /// alert list read is a single round-trip, not N sequential writes.
  Future<void> markAllAlertsRead(List<String> alertIds, String doctorId) async {
    if (alertIds.isEmpty) return;
    final batch = _db.batch();
    for (final id in alertIds) {
      batch.update(_alerts.doc(id), {
        'readBy': FieldValue.arrayUnion([doctorId]),
      });
    }
    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> alertsStream() {
    return _alerts.orderBy('createdAt', descending: true).limit(50).snapshots();
  }

  // ---------------------------------------------------------------
  // Walk-in donor registration
  // ---------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  /// Registers a donor who walks into the hospital/blood bank in
  /// person, without going through the Donor module's own app
  /// sign-up flow. Writes to the SAME `users` collection and the SAME
  /// field names the Donor module and this module's search already
  /// read (`fullName`, `bloodGroup`, `phoneNumber`, `location`,
  /// `role`, `verified`, `availableNow`, `isActive`) so the record is
  /// indistinguishable to every other query in the app - it just
  /// shows up as a normal, staff-verified donor. `registeredBy` /
  /// `source` are additive fields only used to label the entry as
  /// walk-in on this screen; nothing else in the app depends on them.
  Future<String> registerWalkInDonor({
    required String fullName,
    required String bloodGroup,
    required String phoneNumber,
    required String location,
    required String doctorId,
    required String doctorName,
  }) async {
    final doc = await _users.add({
      'fullName': fullName,
      'bloodGroup': bloodGroup,
      'phoneNumber': phoneNumber,
      'location': location,
      'role': 'Donor',
      'verified': true, // staff verified them in person at registration time
      'availableNow': true,
      'isActive': true,
      'source': 'walk-in',
      'registeredBy': doctorId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _auditLogs.add({
      'action': 'walk_in_donor_registered',
      'requestId': doc.id,
      'performedBy': doctorId,
      'performedByName': doctorName,
      'timestamp': FieldValue.serverTimestamp(),
      'details': {'fullName': fullName, 'bloodGroup': bloodGroup},
    });

    return doc.id;
  }
}
