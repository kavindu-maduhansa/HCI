import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hci/screens/donor/emergency_requests_screen.dart';

void main() {
  group('EmergencyRequestsScreen Helper Unit Tests', () {
    test('formatRequestDate handles null and valid DateTime', () {
      expect(EmergencyRequestsScreen.formatRequestDate(null), 'Date not specified');
      expect(
        EmergencyRequestsScreen.formatRequestDate(DateTime(2026, 8, 31, 10, 30)),
        '31 Aug 2026 at 10:30',
      );
    });

    test('formatRequestDate handles ISO string format', () {
      expect(
        EmergencyRequestsScreen.formatRequestDate('2026-12-25T15:45:00.000'),
        '25 Dec 2026 at 15:45',
      );
    });
  });

  testWidgets('EmergencyRequestsScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EmergencyRequestsScreen(),
      ),
    );

    expect(find.text('Emergency Requests'), findsOneWidget);
  });
}
