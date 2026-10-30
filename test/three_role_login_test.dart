import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_flow/login.dart';

void main() {
  testWidgets('Sign In tab does not ask for role; enforces 1 Email = 1 Role Account',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(initialSignUp: false),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify that role selector is NOT in Sign In mode
    expect(find.text('SELECT SIGN IN PORTAL'), findsNothing);
    expect(find.textContaining('1 Email = 1 Role Account'), findsOneWidget);
    expect(find.text('Send Login Code'), findsOneWidget);

    // 2. Switch to Sign Up tab
    final signUpTab = find.text('Sign Up');
    expect(signUpTab, findsOneWidget);
    await tester.tap(signUpTab);
    await tester.pumpAndSettle();

    // 3. Verify Sign Up offers role options
    expect(find.text('SELECT ROLE'), findsOneWidget);
    expect(find.text('1. Provider'), findsOneWidget);
    expect(find.text('2. Receiver'), findsOneWidget);
    expect(find.text('Continue with Provider'), findsOneWidget);

    // 4. Select Receiver option on Sign Up
    final receiverCard = find.text('2. Receiver');
    await tester.tap(receiverCard);
    await tester.pumpAndSettle();

    expect(find.text('Continue with Receiver'), findsOneWidget);
  });
}
