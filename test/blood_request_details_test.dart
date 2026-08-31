import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hci/screens/donor/blood_request_details_screen.dart';

void main() {
  group('BloodRequestDetailsScreen Helper Unit Tests', () {
    test('formatRequestDate handles null and valid DateTime', () {
      expect(BloodRequestDetailsScreen.formatRequestDate(null), 'Not specified');
      expect(
        BloodRequestDetailsScreen.formatRequestDate(DateTime(2026, 8, 31, 14, 30)),
        '31 Aug 2026 at 14:30',
      );
    });

    test('formatRequestDate handles ISO string format', () {
      expect(
        BloodRequestDetailsScreen.formatRequestDate('2026-10-15T09:15:00.000'),
        '15 Oct 2026 at 09:15',
      );
    });

    test('getUrgencyConfig maps urgency levels correctly', () {
      expect(BloodRequestDetailsScreen.getUrgencyConfig('critical').label, 'Critical');
      expect(BloodRequestDetailsScreen.getUrgencyConfig('high').label, 'High Urgency');
      expect(BloodRequestDetailsScreen.getUrgencyConfig('medium').label, 'Medium Urgency');
      expect(BloodRequestDetailsScreen.getUrgencyConfig('low').label, 'Low Urgency');
      expect(BloodRequestDetailsScreen.getUrgencyConfig(null).label, 'Standard');
    });
  });

  testWidgets('BloodRequestDetailsScreen displays request information safely', (WidgetTester tester) async {
    final sampleData = <String, dynamic>{
      'bloodGroup': 'O+',
      'hospitalName': 'National General Hospital',
      'location': 'Colombo, Sri Lanka',
      'urgency': 'critical',
      'requiredUnits': 3,
      'patientName': 'Kasun Perera',
      'contactNumber': '+94771234567',
      'description': 'Urgent requirement for surgical patient.',
      'status': 'active',
      'createdAt': '2026-08-31T10:00:00.000',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: BloodRequestDetailsScreen(
          requestId: 'test_request_123',
          requestData: sampleData,
        ),
      ),
    );

    expect(find.text('Emergency Request Details'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
    expect(find.text('National General Hospital'), findsOneWidget);
    expect(find.text('Colombo, Sri Lanka'), findsOneWidget);
    expect(find.text('3 Units'), findsOneWidget);
    expect(find.text('Kasun Perera'), findsOneWidget);
    expect(find.text('+94771234567'), findsOneWidget);
    expect(find.text('Urgent requirement for surgical patient.'), findsOneWidget);
  });
}
