import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_flow/pages/provider/provider_signup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Provider FSSAI License Verification Tests', () {
    testWidgets('Step 2 displays FSSAI license field with 14-digit limit and verify button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ProviderSignUpPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Fill Step 1 required fields
      final textFields = find.byType(TextFormField);
      // Field 0: Org Name
      await tester.enterText(textFields.at(0), 'Grand Palace Hotel');
      // Field 1: Contact Person
      await tester.enterText(textFields.at(1), 'Chef Rahul');
      // Field 2: Address
      await tester.enterText(textFields.at(2), 'MG Road Bengaluru');
      await tester.pumpAndSettle();

      // Advance to Step 2
      await tester.tap(find.text('Continue to Verification'));
      await tester.pumpAndSettle();

      // Verify Step 2 UI elements
      expect(find.text('14-Digit FSSAI License Number *'), findsOneWidget);
      expect(find.text('Verify FSSAI'), findsOneWidget);
      expect(find.text('Email Verification'), findsOneWidget);

      // Verify Submit button is disabled before FSSAI verification
      final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Submit & Activate Provider Account');
      expect(submitBtnFinder, findsOneWidget);
      final ElevatedButton initialSubmitBtn = tester.widget(submitBtnFinder);
      expect(initialSubmitBtn.onPressed, isNull);

      // Enter invalid FSSAI number (< 14 digits)
      final fssaiField = find.widgetWithText(TextFormField, '14-digit registration (e.g. 11223344556677)');
      await tester.enterText(fssaiField, '12345');
      await tester.pumpAndSettle();

      // Tap Verify FSSAI
      await tester.tap(find.text('Verify FSSAI'));
      await tester.pumpAndSettle();

      // Expect validation error
      expect(find.text('FSSAI License must be a 14-digit number'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(submitBtnFinder).onPressed, isNull);

      // Enter 14-digit number that returns invalid from validation
      await tester.enterText(fssaiField, '00000000000000');
      await tester.pumpAndSettle();

      // Tap Verify FSSAI
      await tester.tap(find.text('Verify FSSAI'));
      await tester.pumpAndSettle();

      // Expect invalid message displayed on screen and submit still disabled
      expect(find.text('Invalid FSSAI License number.'), findsWidgets);
      expect(tester.widget<ElevatedButton>(submitBtnFinder).onPressed, isNull);

      // Enter valid 14-digit FSSAI number
      await tester.enterText(fssaiField, '11223344556677');
      await tester.pumpAndSettle();

      // Tap Verify FSSAI
      await tester.tap(find.text('Verify FSSAI'));
      await tester.pumpAndSettle();

      // Verify verified state
      expect(find.text('Verified'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);

      // After verification, submit button should be enabled
      final ElevatedButton enabledSubmitBtn = tester.widget(submitBtnFinder);
      expect(enabledSubmitBtn.onPressed, isNotNull);
    });
  });
}
