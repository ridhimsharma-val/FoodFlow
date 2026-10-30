import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_flow/login.dart';

void main() {
  testWidgets('LoginPage supports pre-filled role and email when redirected from SignUp',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(
          initialSignUp: false,
          initialRole: UserRole.receiver,
          initialEmail: 'existing_ngo@gmail.com',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify it opened directly in Sign In mode
    expect(find.text('Portal: Receiver'), findsOneWidget);
    expect(find.text('NGO Receiver Portal'), findsOneWidget);

    // Verify email field is pre-filled with the existing account's email
    final emailField = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == 'existing_ngo@gmail.com',
    );
    expect(emailField, findsOneWidget);
  });
}
