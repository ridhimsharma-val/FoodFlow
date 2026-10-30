import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_flow/login.dart';
import 'package:food_flow/pages/provider/provider_dashboard.dart';
import 'package:food_flow/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LocationService persists provider location correctly', () {
    LocationService.setProviderLocationCoords(
      locationName: 'Koramangala 5th Block Kitchen, Bengaluru',
      latitude: 12.9352,
      longitude: 77.6245,
      shortLocation: 'Koramangala, Bengaluru',
    );

    final current = LocationService.currentProviderLocation;
    expect(current, isNotNull);
    expect(current!.formattedAddress, 'Koramangala 5th Block Kitchen, Bengaluru');
    expect(current.shortLocation, 'Koramangala, Bengaluru');
    expect(current.latitude, 12.9352);
    expect(current.longitude, 77.6245);
  });

  testWidgets('LoginPage renders email OTP input and Send Login Code in Sign In mode',
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

    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Send Login Code'), findsOneWidget);
    expect(find.textContaining('1 Email = 1 Role Account'), findsOneWidget);
  });

  testWidgets('ProviderDashboard initializes with location from LocationService',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    LocationService.setProviderLocationCoords(
      locationName: 'HSR Layout Cloud Kitchen, Bengaluru',
      latitude: 12.9121,
      longitude: 77.6446,
      shortLocation: 'HSR Layout, Bengaluru',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ProviderDashboard(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify top bar, greeting badge, and map hub display the location
    expect(find.text('HSR Layout, Bengaluru'), findsWidgets);
    expect(find.textContaining('Operating from: HSR Layout, Bengaluru'), findsOneWidget);
    expect(find.textContaining('Hub: HSR Layout, Bengaluru'), findsOneWidget);
    expect(find.text('Nearby Verified Receivers'), findsOneWidget);
    expect(find.text('List Surplus Food'), findsOneWidget);
  });
}
