import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_flow/main.dart';
import 'package:food_flow/login.dart';
import 'package:food_flow/services/auth_service.dart';
import 'package:food_flow/services/consent_service.dart';
import 'package:food_flow/widgets/terms_and_conditions_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FoodFlowConsentService Unit Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await FoodFlowConsentService.instance.initialize();
      FoodFlowConsentService.instance.resetForTesting(accepted: false);
    });

    test('Initial fresh state requires consent', () {
      expect(FoodFlowConsentService.instance.hasAcceptedCurrentTermsSync(), isFalse);
      expect(FoodFlowConsentService.instance.isConsentActive, isFalse);
      expect(FoodFlowConsentService.instance.hasReadTerms, isFalse);
      expect(FoodFlowConsentService.instance.hasReadPrivacy, isFalse);
      expect(FoodFlowConsentService.instance.hasReadBothDocuments, isFalse);
    });

    test('Reading only Terms marks hasReadTerms true, but not both', () async {
      await FoodFlowConsentService.instance.markTermsAsRead();
      expect(FoodFlowConsentService.instance.hasReadTerms, isTrue);
      expect(FoodFlowConsentService.instance.hasReadPrivacy, isFalse);
      expect(FoodFlowConsentService.instance.hasReadBothDocuments, isFalse);
    });

    test('Reading only Privacy marks hasReadPrivacy true, but not both', () async {
      await FoodFlowConsentService.instance.markPrivacyAsRead();
      expect(FoodFlowConsentService.instance.hasReadTerms, isFalse);
      expect(FoodFlowConsentService.instance.hasReadPrivacy, isTrue);
      expect(FoodFlowConsentService.instance.hasReadBothDocuments, isFalse);
    });

    test('Reading both documents marks hasReadBothDocuments true', () async {
      await FoodFlowConsentService.instance.markTermsAsRead();
      await FoodFlowConsentService.instance.markPrivacyAsRead();
      expect(FoodFlowConsentService.instance.hasReadBothDocuments, isTrue);
    });

    test('Recording consent marks active with version and timestamp', () async {
      final now = DateTime.now().toUtc();
      await FoodFlowConsentService.instance.recordConsent(
        version: FoodFlowConsentService.currentTermsVersion,
        timestamp: now,
      );

      expect(FoodFlowConsentService.instance.hasAcceptedCurrentTermsSync(), isTrue);
      expect(FoodFlowConsentService.instance.isConsentActive, isTrue);
      expect(FoodFlowConsentService.instance.hasReadBothDocuments, isTrue);
      expect(
        FoodFlowConsentService.instance.acceptedVersion,
        equals(FoodFlowConsentService.currentTermsVersion),
      );
      expect(FoodFlowConsentService.instance.acceptedAt, equals(now));
    });

    test('Revoking consent deactivates active consent while preserving audit records', () async {
      final now = DateTime.now().toUtc();
      await FoodFlowConsentService.instance.recordConsent(
        version: FoodFlowConsentService.currentTermsVersion,
        timestamp: now,
      );

      expect(FoodFlowConsentService.instance.hasAcceptedCurrentTermsSync(), isTrue);

      await FoodFlowConsentService.instance.revokeConsent();

      expect(FoodFlowConsentService.instance.hasAcceptedCurrentTermsSync(), isFalse);
      expect(FoodFlowConsentService.instance.isConsentActive, isFalse);
      expect(FoodFlowConsentService.instance.acceptedVersion, equals(FoodFlowConsentService.currentTermsVersion));
      expect(FoodFlowConsentService.instance.acceptedAt, equals(now));
    });

    test('Policy version change requires renewed consent', () async {
      await FoodFlowConsentService.instance.recordConsent(
        version: 'foodflow_terms_v0',
      );

      expect(FoodFlowConsentService.instance.acceptedVersion, equals('foodflow_terms_v0'));
      expect(FoodFlowConsentService.instance.hasAcceptedCurrentTermsSync(), isFalse);
    });

    test('Syncs active consent from authenticated UserProfile', () async {
      final now = DateTime.now().toUtc();
      final profile = UserProfile(
        id: 'usr-123',
        email: 'receiver@ngo.org',
        role: 'receiver',
        termsAcceptedVersion: FoodFlowConsentService.currentTermsVersion,
        termsAcceptedAt: now,
        isTermsConsentActive: true,
      );

      await FoodFlowConsentService.instance.checkAndSyncWithProfile(profile);

      expect(FoodFlowConsentService.instance.hasAcceptedCurrentTermsSync(), isTrue);
    });
  });

  group('Terms & Privacy Separate Document & Consent Flow Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await FoodFlowConsentService.instance.initialize();
      FoodFlowConsentService.instance.resetForTesting(accepted: false);
    });

    testWidgets('1 & 3: Opening Terms displays only Terms & Conditions with 8 sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => TermsAndConditionsDialog.showTerms(context),
                child: const Text('Open Terms'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Terms'));
      await tester.pumpAndSettle();

      // Title & Subtitle
      expect(find.text('TERMS & CONDITIONS'), findsOneWidget);
      expect(find.text('Platform Agreement & Operating Terms'), findsOneWidget);

      // Verify sections in Terms
      expect(find.text('1. Platform Role & Legal Responsibilities'), findsOneWidget);
      expect(find.text('2. Food Safety & Regulatory Compliance'), findsOneWidget);
      expect(find.text('3. Claims, Pickup & Delivery Verification'), findsOneWidget);
      expect(find.text('8. Agreement & Updates'), findsOneWidget);

      // Verify Privacy Policy sections are NOT mixed into Terms content
      expect(find.text('11. Contact & Grievance Redressal'), findsNothing);
      expect(find.text('4. Location & Live GPS Privacy'), findsNothing);
    });

    testWidgets('2 & 4: Opening Privacy Policy displays distinct 11 sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => TermsAndConditionsDialog.showPrivacy(context),
                child: const Text('Open Privacy'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Privacy'));
      await tester.pumpAndSettle();

      // Title & Subtitle
      expect(find.text('PRIVACY POLICY'), findsOneWidget);
      expect(find.text('Data Processing & Privacy Notice'), findsOneWidget);

      // Verify distinct 11 sections in Privacy Policy
      expect(find.text('1. Introduction'), findsOneWidget);
      expect(find.text('2. Information We Collect'), findsOneWidget);
      expect(find.text('3. How We Use Your Information'), findsOneWidget);
      expect(find.text('4. Location & Live GPS Privacy'), findsOneWidget);
      expect(find.text('5. Data Sharing & Disclosure'), findsOneWidget);
      expect(find.text('6. Data Security'), findsOneWidget);
      expect(find.text('7. Data Retention & Deletion'), findsOneWidget);
      expect(find.text('8. Your Privacy Rights & Choices'), findsOneWidget);
      expect(find.text('9. Children\'s Information'), findsOneWidget);
      expect(find.text('10. Changes to This Privacy Policy'), findsOneWidget);
      expect(find.text('11. Contact & Grievance Redressal'), findsOneWidget);
    });

    testWidgets('5, 6 & 7: Checkbox is locked when reviewing only one doc; unlocks when both are reviewed', (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => TermsAndConditionsDialog.showTerms(context),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // 5. Scroll to bottom of Terms
      final scrollableFinder = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.text('LEGAL DOCUMENT REVIEW PROGRESS'),
        500,
        scrollable: scrollableFinder,
      );
      await tester.pumpAndSettle();

      // Terms is read, but Privacy is not yet read -> checkbox is disabled
      expect(FoodFlowConsentService.instance.hasReadTerms, isTrue);
      expect(FoodFlowConsentService.instance.hasReadPrivacy, isFalse);
      final checkboxWhenOnlyTerms = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkboxWhenOnlyTerms.onChanged, isNull);

      // 6. Switch to Privacy Policy and review
      await tester.tap(find.text('Review Privacy Policy ➔'));
      await tester.pumpAndSettle();

      expect(find.text('PRIVACY POLICY'), findsOneWidget);

      // Scroll to bottom of Privacy Policy
      await tester.scrollUntilVisible(
        find.text('LEGAL DOCUMENT REVIEW PROGRESS'),
        500,
        scrollable: scrollableFinder,
      );
      await tester.pumpAndSettle();

      // 7. Both documents are now reviewed! Checkbox must be UNLOCKED
      expect(FoodFlowConsentService.instance.hasReadBothDocuments, isTrue);
      final unlockedCheckbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(unlockedCheckbox.onChanged, isNotNull);

      // 8. User manually checks the checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Modal closes automatically and consent is recorded
      expect(find.text('PRIVACY POLICY'), findsNothing);
      expect(FoodFlowConsentService.instance.hasAcceptedCurrentTermsSync(), isTrue);
    });

    testWidgets('9 & 10: Yellow CTA navigates after consent, blocks when revoked', (tester) async {
      // Simulate consent accepted
      FoodFlowConsentService.instance.resetForTesting(accepted: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.style?.backgroundColor?.resolve({}), equals(AppColors.primaryGold));

      // 9. Tapping yellow button navigates to LoginPage
      await tester.tap(find.text('Go to Login & Setup'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      // 10. Simulate user revokes consent
      await FoodFlowConsentService.instance.revokeConsent();

      // Clear route stack and return to WelcomeScreen
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Button remains yellow, but tapping shows reminder SnackBar and blocks navigation
      final yellowBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(yellowBtn.style?.backgroundColor?.resolve({}), equals(AppColors.primaryGold));

      await tester.tap(find.text('Go to Login & Setup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Please read the Terms & Conditions and accept them before continuing.'),
        findsOneWidget,
      );
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('12: Responsive layouts: Mobile renders bottom sheet, Desktop renders dialog', (tester) async {
      // Mobile screen test (<650 width)
      tester.view.physicalSize = const Size(420, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => TermsAndConditionsDialog.showTerms(context),
                child: const Text('Open Terms'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Terms'));
      await tester.pumpAndSettle();

      expect(find.byType(TermsAndConditionsDialog), findsOneWidget);
      final mobileWidget = tester.widget<TermsAndConditionsDialog>(find.byType(TermsAndConditionsDialog));
      expect(mobileWidget.isBottomSheet, isTrue);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // Desktop screen test (>=650 width)
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => TermsAndConditionsDialog.showPrivacy(context),
                child: const Text('Open Privacy'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Privacy'));
      await tester.pumpAndSettle();

      expect(find.byType(TermsAndConditionsDialog), findsOneWidget);
      final desktopWidget = tester.widget<TermsAndConditionsDialog>(find.byType(TermsAndConditionsDialog));
      expect(desktopWidget.isBottomSheet, isFalse);
    });
  });
}
