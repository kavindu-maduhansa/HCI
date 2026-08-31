import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hci/screens/donor/donor_profile_screen.dart';

void main() {
  testWidgets('DonorProfileScreen unauthenticated fallback smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DonorProfileScreen(),
      ),
    );

    expect(find.text('Donor Profile'), findsOneWidget);
    expect(find.text('User is not signed in.'), findsOneWidget);
  });
}
