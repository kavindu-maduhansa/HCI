import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hci/screens/donor/donation_history_screen.dart';

void main() {
  group('DonationHistoryScreen Helper Unit Tests', () {
    test('formatDonationDate handles null and valid DateTime', () {
      expect(DonationHistoryScreen.formatDonationDate(null), 'Date not available');
      expect(
        DonationHistoryScreen.formatDonationDate(DateTime(2026, 8, 15, 10, 0)),
        '15 Aug 2026',
      );
    });

    test('formatDonationDate handles ISO string format', () {
      expect(
        DonationHistoryScreen.formatDonationDate('2026-05-20T14:30:00.000'),
        '20 May 2026',
      );
    });

    test('getStatusConfig maps statuses accurately and case-insensitively', () {
      expect(DonationHistoryScreen.getStatusConfig('completed').label, 'Completed');
      expect(DonationHistoryScreen.getStatusConfig('COMPLETED').label, 'Completed');
      expect(DonationHistoryScreen.getStatusConfig('verified').label, 'Verified');
      expect(DonationHistoryScreen.getStatusConfig('pending').label, 'Pending');
      expect(DonationHistoryScreen.getStatusConfig('cancelled').label, 'Cancelled');
      expect(DonationHistoryScreen.getStatusConfig('CANCELED').label, 'Cancelled');
      expect(DonationHistoryScreen.getStatusConfig(null).label, 'Unknown');
      expect(DonationHistoryScreen.getStatusConfig('custom_status').label, 'custom_status');
    });
  });

  testWidgets('DonationHistoryScreen smoke test without authenticated user', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DonationHistoryScreen(),
      ),
    );

    expect(find.text('Donation History'), findsOneWidget);
  });
}
