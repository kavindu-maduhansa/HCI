import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hci/screens/donor/my_responses_screen.dart';

void main() {
  group('MyResponsesScreen Helper Unit Tests', () {
    test('formatResponseDate handles null and valid DateTime', () {
      expect(MyResponsesScreen.formatResponseDate(null), 'Recently submitted');
      expect(
        MyResponsesScreen.formatResponseDate(DateTime(2026, 8, 31, 15, 45)),
        '31 Aug 2026 at 15:45',
      );
    });

    test('formatResponseDate handles ISO string format', () {
      expect(
        MyResponsesScreen.formatResponseDate('2026-11-20T08:30:00.000'),
        '20 Nov 2026 at 08:30',
      );
    });

    test('getStatusConfig maps statuses accurately and case-insensitively', () {
      expect(MyResponsesScreen.getStatusConfig('pending').label, 'Pending Review');
      expect(MyResponsesScreen.getStatusConfig('PENDING').label, 'Pending Review');
      expect(MyResponsesScreen.getStatusConfig('accepted').label, 'Accepted');
      expect(MyResponsesScreen.getStatusConfig('APPROVED').label, 'Accepted');
      expect(MyResponsesScreen.getStatusConfig('rejected').label, 'Rejected');
      expect(MyResponsesScreen.getStatusConfig('DECLINED').label, 'Rejected');
      expect(MyResponsesScreen.getStatusConfig(null).label, 'Pending Review');
      expect(MyResponsesScreen.getStatusConfig('unknown_status').label, 'Pending Review');
    });
  });

  testWidgets('MyResponsesScreen smoke test without authenticated user', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MyResponsesScreen(),
      ),
    );

    expect(find.text('My Responses'), findsOneWidget);
  });
}
