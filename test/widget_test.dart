// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hci/screens/auth/register_screen.dart';
import 'package:hci/screens/donor/donor_home_screen.dart';
import 'package:hci/screens/recipient/recipient_home_screen.dart';
import 'package:hci/screens/hospital/hospital_home_screen.dart';
import 'package:hci/screens/coordinator/organisation_home_screen.dart';

void main() {
  testWidgets('RegisterScreen smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Select your role'), findsOneWidget);
    expect(find.text('Donor'), findsOneWidget);
  });

  testWidgets('DonorHomeScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DonorHomeScreen(),
      ),
    );
    expect(find.text('Donor Dashboard'), findsOneWidget);
    expect(find.text('Your Donation Profile'), findsOneWidget);
  });

  testWidgets('RecipientHomeScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RecipientHomeScreen(),
      ),
    );
    expect(find.text('Recipient Home'), findsOneWidget);
    expect(find.text('Recipient Area'), findsOneWidget);
  });

  testWidgets('HospitalHomeScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HospitalHomeScreen(),
      ),
    );
    expect(find.text('Hospital Home'), findsOneWidget);
    expect(find.text('Hospital Area'), findsOneWidget);
  });

  testWidgets('OrganisationHomeScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OrganisationHomeScreen(),
      ),
    );
    expect(find.text('Organisation Home'), findsOneWidget);
    expect(find.text('Organisation Area'), findsOneWidget);
  });
}
