import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_flow/main.dart';
import 'package:food_flow/login.dart';
import 'package:food_flow/pages/provider/provider_signup.dart';
import 'package:food_flow/pages/receiver/receiver_signup.dart';
import 'package:food_flow/pages/volunteer/volunteer_signup.dart';

import 'package:food_flow/services/consent_service.dart';

void main() {
  testWidgets('End-to-end navigation across all 3 role signup pages with improved UX',
      (WidgetTester tester) async {
    FoodFlowConsentService.instance.resetForTesting(accepted: true);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Build app and verify WelcomeScreen
    await tester.pumpWidget(const FoodFlowApp());
    await tester.pumpAndSettle();
    expect(find.text('Food Flow'), findsOneWidget);

    // 2. Navigate to LoginPage
    await tester.tap(find.text('Go to Login & Setup'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    // 3. Test Provider Navigation & Stepper
    await tester.tap(find.text('1. Provider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Provider'));
    await tester.pumpAndSettle();
    expect(find.byType(ProviderSignUpPage), findsOneWidget);
    expect(find.text('Sign Up as Food Provider'), findsOneWidget);
    expect(find.text('Continue to Verification'), findsOneWidget);

    // Advance to Step 2
    await tester.tap(find.text('Continue to Verification'));
    await tester.pumpAndSettle();
    expect(find.text('Email Verification'), findsWidgets);

    // Return to LoginPage
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    // 4. Test Receiver Navigation
    await tester.tap(find.text('2. Receiver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Receiver'));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiverSignUpPage), findsOneWidget);
    expect(find.text('Sign Up as Relief Receiver'), findsOneWidget);
    expect(find.text('Verify & Complete NGO Registration'), findsOneWidget);

    // Return to LoginPage
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    // 5. Test Volunteer Navigation
    await tester.tap(find.text('3. Volunteer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Volunteer'));
    await tester.pumpAndSettle();
    expect(find.byType(VolunteerSignUpPage), findsOneWidget);
    expect(find.text('Sign Up as Food Flow Volunteer'), findsOneWidget);
    expect(find.text('Join Volunteer Delivery Network'), findsOneWidget);

    // Test Back Navigation
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
