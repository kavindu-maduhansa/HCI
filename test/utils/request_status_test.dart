import 'package:flutter_test/flutter_test.dart';

import 'package:hci/utils/request_status.dart';

/// Unit tests for the Doctor/Blood Bank module's shared status/urgency
/// vocabulary in lib/utils/request_status.dart. This file is pure Dart
/// logic (no Firebase, no widgets) so it is tested directly rather
/// than through a widget test - fast, deterministic, and exercises the
/// exact rules every screen in this module relies on (status
/// transitions, donor eligibility, blood compatibility, and the
/// RequestHealth SLA heuristic).
void main() {
  group('RequestStatus.isValidTransition', () {
    test('pending can move to verified or rejected', () {
      expect(RequestStatus.isValidTransition(RequestStatus.pending, RequestStatus.verified), isTrue);
      expect(RequestStatus.isValidTransition(RequestStatus.pending, RequestStatus.rejected), isTrue);
    });

    test('pending cannot jump straight to fulfilled', () {
      expect(RequestStatus.isValidTransition(RequestStatus.pending, RequestStatus.fulfilled), isFalse);
    });

    test('fulfilled and rejected are terminal (no forward transitions), except rejected -> pending re-verification', () {
      expect(RequestStatus.isValidTransition(RequestStatus.fulfilled, RequestStatus.verified), isFalse);
      expect(RequestStatus.isValidTransition(RequestStatus.rejected, RequestStatus.pending), isTrue);
      expect(RequestStatus.isValidTransition(RequestStatus.rejected, RequestStatus.verified), isFalse);
    });

    test('a status transitioning to itself is always allowed (no-op update)', () {
      expect(RequestStatus.isValidTransition(RequestStatus.matched, RequestStatus.matched), isTrue);
    });

    test('matched can fall back to verified (donor declined) or move to fulfilled', () {
      expect(RequestStatus.isValidTransition(RequestStatus.matched, RequestStatus.verified), isTrue);
      expect(RequestStatus.isValidTransition(RequestStatus.matched, RequestStatus.fulfilled), isTrue);
    });
  });

  group('RequestStatus.label', () {
    test('known statuses get a human label distinct from the raw value', () {
      expect(RequestStatus.label(RequestStatus.pending), isNot(RequestStatus.pending));
      expect(RequestStatus.label(RequestStatus.fulfilled), 'Fulfilled');
    });

    test('an unrecognised status falls back to the raw string instead of crashing', () {
      expect(RequestStatus.label('some_future_status'), 'some_future_status');
    });
  });

  group('UrgencyLevel.weight', () {
    test('critical sorts before high, which sorts before normal', () {
      expect(UrgencyLevel.weight(UrgencyLevel.critical), lessThan(UrgencyLevel.weight(UrgencyLevel.high)));
      expect(UrgencyLevel.weight(UrgencyLevel.high), lessThan(UrgencyLevel.weight(UrgencyLevel.normal)));
    });
  });

  group('DonorEligibility (90-day rule)', () {
    test('a donor with no donation history is eligible by default', () {
      expect(DonorEligibility.isEligible(null), isTrue);
      expect(DonorEligibility.daysUntilEligible(null), isNull);
    });

    test('a donor who donated 89 days ago is not yet eligible', () {
      final lastDonation = DateTime.now().subtract(const Duration(days: 89));
      expect(DonorEligibility.isEligible(lastDonation), isFalse);
      expect(DonorEligibility.daysUntilEligible(lastDonation), 1);
    });

    test('a donor who donated exactly 90 days ago is eligible', () {
      final lastDonation = DateTime.now().subtract(const Duration(days: 90));
      expect(DonorEligibility.isEligible(lastDonation), isTrue);
      expect(DonorEligibility.daysUntilEligible(lastDonation), isNull);
    });

    test('a donor who donated 200 days ago is eligible', () {
      final lastDonation = DateTime.now().subtract(const Duration(days: 200));
      expect(DonorEligibility.isEligible(lastDonation), isTrue);
    });
  });

  group('BloodCompatibility.compatibleDonorGroups', () {
    test('O- recipients can only receive from O- (the universal donor)', () {
      expect(BloodCompatibility.compatibleDonorGroups('O-'), ['O-']);
    });

    test('AB+ recipients can receive from every group (the universal recipient)', () {
      expect(BloodCompatibility.compatibleDonorGroups('AB+'), hasLength(8));
    });

    test('is case- and whitespace-insensitive on the recipient group', () {
      expect(BloodCompatibility.compatibleDonorGroups(' o+ '), BloodCompatibility.compatibleDonorGroups('O+'));
    });

    test('an unknown group falls back to itself rather than an empty list', () {
      expect(BloodCompatibility.compatibleDonorGroups('XX'), ['XX']);
    });
  });

  group('WaitingTime.format', () {
    test('a null createdAt renders as an em dash placeholder, not a crash', () {
      expect(WaitingTime.format(null), '—');
    });

    test('formats seconds, minutes and hours in the expected shape', () {
      expect(WaitingTime.format(DateTime.now().subtract(const Duration(seconds: 30))), endsWith('s'));
      expect(WaitingTime.format(DateTime.now().subtract(const Duration(minutes: 5))), contains('m'));
      expect(WaitingTime.format(DateTime.now().subtract(const Duration(hours: 3))), contains('h'));
      expect(WaitingTime.format(DateTime.now().subtract(const Duration(days: 2))), contains('d'));
    });
  });

  group('RequestHealth.computeLevel', () {
    test('a closed request (fulfilled/rejected/expired) is always ON_TRACK regardless of waiting time', () {
      final level = RequestHealth.computeLevel(
        status: RequestStatus.fulfilled,
        urgency: UrgencyLevel.critical,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        unitsNeeded: 2,
        unitsConfirmed: 0,
      );
      expect(level, RequestHealth.onTrack);
    });

    test('a fully unit-confirmed request is ON_TRACK even if it waited a long time', () {
      final level = RequestHealth.computeLevel(
        status: RequestStatus.matched,
        urgency: UrgencyLevel.critical,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        unitsNeeded: 2,
        unitsConfirmed: 2,
      );
      expect(level, RequestHealth.onTrack);
    });

    test('a Critical request past its 30-minute critical threshold is CRITICAL_ATTENTION', () {
      final level = RequestHealth.computeLevel(
        status: RequestStatus.pending,
        urgency: UrgencyLevel.critical,
        createdAt: DateTime.now().subtract(const Duration(minutes: 31)),
        unitsNeeded: 2,
        unitsConfirmed: 0,
      );
      expect(level, RequestHealth.criticalAttention);
    });

    test('a Critical request past 15 minutes but under 30 is NEEDS_ATTENTION', () {
      final level = RequestHealth.computeLevel(
        status: RequestStatus.pending,
        urgency: UrgencyLevel.critical,
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
        unitsNeeded: 2,
        unitsConfirmed: 0,
      );
      expect(level, RequestHealth.needsAttention);
    });

    test('a Normal request waiting 60 minutes is still ON_TRACK (its SLA window is 120m)', () {
      final level = RequestHealth.computeLevel(
        status: RequestStatus.pending,
        urgency: UrgencyLevel.normal,
        createdAt: DateTime.now().subtract(const Duration(minutes: 60)),
        unitsNeeded: 2,
        unitsConfirmed: 0,
      );
      expect(level, RequestHealth.onTrack);
    });
  });

  group('RequestHealth.reasons', () {
    test('a closed request returns a single short-circuit reason, not the full breakdown', () {
      final reasons = RequestHealth.reasons(
        status: RequestStatus.rejected,
        urgency: UrgencyLevel.high,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        unitsNeeded: 1,
        unitsConfirmed: 0,
      );
      expect(reasons, hasLength(1));
      expect(reasons.first, contains('closed'));
    });

    test('an active, under-threshold request explains waiting time, SLA thresholds and coverage', () {
      final reasons = RequestHealth.reasons(
        status: RequestStatus.pending,
        urgency: UrgencyLevel.high,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        unitsNeeded: 4,
        unitsConfirmed: 1,
      );
      expect(reasons.any((r) => r.contains('Waiting time')), isTrue);
      expect(reasons.any((r) => r.contains('SLA')), isTrue);
      expect(reasons.any((r) => r.contains('25%')), isTrue); // 1 of 4 = 25% coverage
    });
  });
}
