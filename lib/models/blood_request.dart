import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single emergency blood request document from the
/// `requests` Firestore collection.
///
/// Team integration note: `patientName`, `bloodGroup`, `unitsNeeded`,
/// `urgency`, `hospitalName`, `location`, `notes`, `createdBy`,
/// `createdByName`, `status`, `createdAt` are the Recipient module's
/// original fields and are read as-is here, unchanged. Every field
/// added below by the Doctor module (`unitsConfirmed`,
/// `donorsNotifiedCount`, `donorsAcceptedCount`, `pinnedBy`) is
/// additive and defaults safely to 0/empty when absent, so it never
/// breaks a request document written before this upgrade.
class BloodRequest {
  final String id;
  final String patientName;
  final String bloodGroup;
  final int unitsNeeded;
  final String urgency; // Critical, High, Normal
  final String hospitalName;
  final String location;
  final String notes;
  final String createdBy;
  final String createdByName;
  final String status; // pending, verified, matched, fulfilled, rejected, expired
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Doctor-module additions (all additive / backward compatible).
  final int unitsConfirmed;
  final int donorsNotifiedCount;
  final int donorsAcceptedCount;
  final List<String> pinnedBy;

  // #two-person-verification - Critical urgency requests require a
  // second, different staff member to co-sign before the request
  // actually moves to `verified`. These three fields record who gave
  // the first approval and when; they stay null for every other
  // urgency level and for requests verified before this feature.
  final String? firstApproverId;
  final String? firstApproverName;
  final DateTime? firstApprovedAt;

  const BloodRequest({
    required this.id,
    required this.patientName,
    required this.bloodGroup,
    required this.unitsNeeded,
    required this.urgency,
    required this.hospitalName,
    required this.location,
    required this.notes,
    required this.createdBy,
    required this.createdByName,
    required this.status,
    this.verifiedBy,
    this.verifiedAt,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.unitsConfirmed = 0,
    this.donorsNotifiedCount = 0,
    this.donorsAcceptedCount = 0,
    this.pinnedBy = const [],
    this.firstApproverId,
    this.firstApproverName,
    this.firstApprovedAt,
  });

  int get unitsRemaining => (unitsNeeded - unitsConfirmed).clamp(0, unitsNeeded);

  bool isPinnedBy(String? uid) => uid != null && pinnedBy.contains(uid);

  /// True only for a Critical-urgency request that has its first
  /// co-sign recorded but has not yet been fully verified by a second,
  /// different staff member.
  bool get awaitingSecondApproval => urgency == 'Critical' && status == 'pending' && firstApproverId != null;

  factory BloodRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return BloodRequest(
      id: doc.id,
      patientName: (data['patientName'] as String?)?.trim().isNotEmpty == true
          ? data['patientName'] as String
          : 'Unknown Patient',
      bloodGroup: data['bloodGroup'] as String? ?? '-',
      unitsNeeded: (data['unitsNeeded'] as num?)?.toInt() ?? 1,
      urgency: data['urgency'] as String? ?? 'Normal',
      hospitalName: data['hospitalName'] as String? ?? '-',
      location: data['location'] as String? ?? '-',
      notes: data['notes'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Recipient',
      status: data['status'] as String? ?? 'pending',
      verifiedBy: data['verifiedBy'] as String?,
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      unitsConfirmed: (data['unitsConfirmed'] as num?)?.toInt() ?? 0,
      donorsNotifiedCount: (data['donorsNotifiedCount'] as num?)?.toInt() ?? 0,
      donorsAcceptedCount: (data['donorsAcceptedCount'] as num?)?.toInt() ?? 0,
      pinnedBy: (data['pinnedBy'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      firstApproverId: data['firstApproverId'] as String?,
      firstApproverName: data['firstApproverName'] as String?,
      firstApprovedAt: (data['firstApprovedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Represents a single donor's response record inside a request's
/// `responses` subcollection (FR10 - donor response tracking).
class DonorResponseRecord {
  final String id;
  final String donorId;
  final String donorName;
  final String donorPhone;
  final String bloodGroup;
  final String status; // notified, accepted, declined, completed
  final String notifiedBy;
  final DateTime? notifiedAt;
  final DateTime? respondedAt;
  final int unitsPledged;

  const DonorResponseRecord({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.donorPhone,
    required this.bloodGroup,
    required this.status,
    required this.notifiedBy,
    this.notifiedAt,
    this.respondedAt,
    this.unitsPledged = 1,
  });

  factory DonorResponseRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return DonorResponseRecord(
      id: doc.id,
      donorId: data['donorId'] as String? ?? '',
      donorName: data['donorName'] as String? ?? 'Donor',
      donorPhone: data['donorPhone'] as String? ?? '',
      bloodGroup: data['bloodGroup'] as String? ?? '-',
      status: data['status'] as String? ?? 'notified',
      notifiedBy: data['notifiedBy'] as String? ?? '',
      notifiedAt: (data['notifiedAt'] as Timestamp?)?.toDate(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      unitsPledged: (data['unitsPledged'] as num?)?.toInt() ?? 1,
    );
  }
}
