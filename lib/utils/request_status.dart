import 'package:flutter/material.dart';

/// Shared status/urgency vocabulary + color mapping used across the
/// Hospital/Doctor dashboard so every tab renders requests consistently.
///
/// IMPORTANT (team integration): these string VALUES
/// (pending/verified/matched/fulfilled/rejected/expired) are the ones
/// already written to the shared `requests.status` field and used by
/// this module in production. They are intentionally NOT renamed to
/// avoid breaking the Recipient team's integration - only new,
/// additive fields were introduced in this upgrade.
class RequestStatus {
  static const pending = 'pending';
  static const verified = 'verified';
  static const matched = 'matched';
  static const fulfilled = 'fulfilled';
  static const rejected = 'rejected';
  static const expired = 'expired';

  static const List<String> activeStatuses = [pending, verified, matched];
  static const List<String> historyStatuses = [fulfilled, rejected, expired];

  /// Allowed forward transitions for the Doctor-driven part of the
  /// workflow (operational validation only - see #20). Rejected and
  /// fulfilled/expired requests are terminal and cannot silently
  /// become active again; a rejected request can only move forward
  /// through the explicit re-verification flow (back to `pending`).
  static const Map<String, List<String>> _allowedTransitions = {
    pending: [verified, rejected],
    verified: [matched, rejected],
    matched: [verified, fulfilled], // verified = donor declined, back to search
    fulfilled: [],
    rejected: [pending], // re-verification workflow only
    expired: [pending],
  };

  static bool isValidTransition(String from, String to) {
    if (from == to) return true;
    return _allowedTransitions[from]?.contains(to) ?? false;
  }

  static String label(String status) {
    switch (status) {
      case pending:
        return 'Pending Verification';
      case verified:
        return 'Verified · Awaiting Donor';
      case matched:
        return 'Donor(s) Matched';
      case fulfilled:
        return 'Fulfilled';
      case rejected:
        return 'Rejected';
      case expired:
        return 'Expired';
      default:
        return status;
    }
  }

  static Color color(String status) {
    switch (status) {
      case pending:
        return const Color(0xFFF59E0B); // amber
      case verified:
        return const Color(0xFF2563EB); // blue
      case matched:
        return const Color(0xFF7C3AED); // violet
      case fulfilled:
        return const Color(0xFF2E7D32); // green
      case rejected:
        return const Color(0xFF6B7280); // grey
      case expired:
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF6B7280);
    }
  }

  static IconData icon(String status) {
    switch (status) {
      case pending:
        return Icons.hourglass_top_rounded;
      case verified:
        return Icons.verified_rounded;
      case matched:
        return Icons.link_rounded;
      case fulfilled:
        return Icons.check_circle_rounded;
      case rejected:
        return Icons.cancel_rounded;
      case expired:
        return Icons.event_busy_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}

class UrgencyLevel {
  static const critical = 'Critical';
  static const high = 'High';
  static const normal = 'Normal';

  static const List<String> all = [critical, high, normal];

  static Color color(String urgency) {
    switch (urgency) {
      case critical:
        return const Color(0xFFC62828);
      case high:
        return const Color(0xFFEF6C00);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  /// Sort weight so critical requests can be surfaced first
  /// (lower = higher priority).
  static int weight(String urgency) {
    switch (urgency) {
      case critical:
        return 0;
      case high:
        return 1;
      default:
        return 2;
    }
  }
}

/// Donor eligibility helper — implements the standard 90-day
/// inter-donation gap rule so staff can see at a glance whether a
/// donor is currently eligible.
class DonorEligibility {
  static const minGapDays = 90;

  static bool isEligible(DateTime? lastDonationDate) {
    if (lastDonationDate == null) return true;
    final daysSince = DateTime.now().difference(lastDonationDate).inDays;
    return daysSince >= minGapDays;
  }

  static int? daysUntilEligible(DateTime? lastDonationDate) {
    if (lastDonationDate == null) return null;
    final daysSince = DateTime.now().difference(lastDonationDate).inDays;
    final remaining = minGapDays - daysSince;
    return remaining > 0 ? remaining : null;
  }
}

/// Standard blood-group donor compatibility matrix, used by the
/// Doctor's donor search (FR09) to surface medically compatible
/// donors for a given patient's required blood group.
class BloodCompatibility {
  static const Map<String, List<String>> _donorsFor = {
    'O-': ['O-'],
    'O+': ['O+', 'O-'],
    'A-': ['A-', 'O-'],
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'AB-': ['AB-', 'A-', 'B-', 'O-'],
    'AB+': ['AB+', 'AB-', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-'],
  };

  static List<String> compatibleDonorGroups(String recipientGroup) {
    return _donorsFor[recipientGroup.trim().toUpperCase()] ?? [recipientGroup];
  }
}

/// Formats the elapsed time since a request was created, e.g.
/// "14m 32s", "2h 5m", "3d 4h". Purely derived from the Firestore
/// `createdAt` timestamp - nothing is hard-coded.
class WaitingTime {
  static String format(DateTime? createdAt) {
    if (createdAt == null) return '—';
    final d = DateTime.now().difference(createdAt);
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    if (d.inHours < 24) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inDays}d ${d.inHours % 24}h';
  }

  static Duration elapsed(DateTime? createdAt) {
    if (createdAt == null) return Duration.zero;
    return DateTime.now().difference(createdAt);
  }
}

/// Operational (NOT medical) health indicator for an active request.
///
/// This is an application-level SLA heuristic only - it flags requests
/// that have been waiting a long time relative to their stated
/// urgency and unit-fulfilment progress, so staff can triage their
/// workload. It does not represent any clinical judgement about the
/// patient.
class RequestHealth {
  static const onTrack = 'ON_TRACK';
  static const needsAttention = 'NEEDS_ATTENTION';
  static const criticalAttention = 'CRITICAL_ATTENTION';

  // Operational SLA thresholds (minutes) by urgency, for a request
  // that is not yet fully unit-confirmed. Tune-able app policy, not a
  // medical claim.
  static const Map<String, List<int>> _thresholdsMinutes = {
    UrgencyLevel.critical: [15, 30], // [attention, critical]
    UrgencyLevel.high: [45, 90],
    UrgencyLevel.normal: [120, 240],
  };

  static String computeLevel({
    required String status,
    required String urgency,
    required DateTime? createdAt,
    required int unitsNeeded,
    required int unitsConfirmed,
  }) {
    if ([RequestStatus.fulfilled, RequestStatus.rejected, RequestStatus.expired].contains(status)) {
      return onTrack;
    }
    final fullyConfirmed = unitsNeeded > 0 && unitsConfirmed >= unitsNeeded;
    if (fullyConfirmed) return onTrack;

    final waitingMinutes = WaitingTime.elapsed(createdAt).inMinutes;
    final thresholds = _thresholdsMinutes[urgency] ?? _thresholdsMinutes[UrgencyLevel.normal]!;

    if (waitingMinutes >= thresholds[1]) return criticalAttention;
    if (waitingMinutes >= thresholds[0]) return needsAttention;
    return onTrack;
  }

  static String label(String level) {
    switch (level) {
      case needsAttention:
        return 'Needs Attention';
      case criticalAttention:
        return 'Immediate Attention';
      default:
        return 'On Track';
    }
  }

  static Color color(String level) {
    switch (level) {
      case needsAttention:
        return const Color(0xFFF59E0B);
      case criticalAttention:
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF2E7D32);
    }
  }
}
