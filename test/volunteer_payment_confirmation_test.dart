import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:food_flow/services/food_rescue_service.dart';
import 'package:food_flow/pages/volunteer/volunteer_payment_confirmation_page.dart';
import 'package:food_flow/pages/volunteer/volunteer_payments_page.dart';
import 'package:food_flow/pages/volunteer/volunteer_dashboard.dart';

void main() {
  final testBatch = SurplusBatch(
    id: 'TEST-PAY-1234',
    providerName: 'Spice Symphony',
    providerCategory: 'Commercial Restaurant',
    location: const LatLng(12.9352, 77.6245),
    title: 'Veg Biryani Special',
    category: 'Cooked Meals',
    quantityPortions: 45,
    dietaryType: 'Pure Veg',
    cookedAt: DateTime.now().subtract(const Duration(hours: 3)),
    safeUntil: DateTime.now().add(const Duration(hours: 2)),
    temperatureCelsius: 65.0,
    packagingType: 'Thermal Cambros',
    pickupAddress: 'Koramangala 5th Block, Bengaluru',
    pickupOtp: '5821',
    deliveryOtp: '9341',
    basePrice: 50.0,
    floorPrice: 15.0,
    status: BatchStatus.delivered,
    claimedByNgo: 'Asha Food Relief NGO',
    deliveredAt: DateTime.now().subtract(const Duration(minutes: 30)),
  );

  testWidgets('VolunteerPaymentConfirmationPage renders full payment detail and confirmation receipt', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VolunteerPaymentConfirmationPage(batch: testBatch),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Hero Banner
    expect(find.text('Payment Details & Confirmation'), findsOneWidget);
    expect(find.text('Payment Confirmed & Settled'), findsOneWidget);
    expect(find.text('Disbursed instantly via Food Flow Smart Courier Escrow'), findsOneWidget);
    expect(find.text('PAID ✓'), findsOneWidget);

    // Verify Dual-OTP Authentication Proof
    expect(find.text('Dual-OTP Authentication Proof'), findsOneWidget);
    expect(find.textContaining('Provider Pickup OTP: 5821'), findsOneWidget);
    expect(find.textContaining('Receiver Delivery OTP: 9341'), findsOneWidget);
    expect(find.text('Verified at Provider Dock ✓'), findsOneWidget);
    expect(find.text('Verified at Dropoff Intake ✓'), findsOneWidget);

    // Verify Volunteer Courier Earnings Breakdown
    expect(find.text('Volunteer Earnings Breakdown'), findsOneWidget);
    expect(find.text('Base Transit Allowance'), findsOneWidget);
    expect(find.text('Rapid Dispatch Safe-Window Bonus'), findsOneWidget);
    expect(find.text('Total Courier Payout'), findsOneWidget);

    // Verify Food Batch Details
    expect(find.text('Food Batch & Dynamic Pricing Settlement'), findsOneWidget);
    expect(find.textContaining('Spice Symphony'), findsWidgets);
    expect(find.textContaining('Asha Food Relief NGO'), findsWidgets);

    // Verify Banking & Transaction Reference
    expect(find.text('Escrow Banking & Transaction Reference'), findsOneWidget);
    expect(find.textContaining('TXN-FF-TESTPAY1'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('Download Tax-Exempt Receipt (PDF)'), findsOneWidget);
    expect(find.text('Back to Volunteer Dashboard'), findsOneWidget);
  });

  testWidgets('VolunteerPaymentsPage renders overview stats and payment confirmations list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VolunteerPaymentsPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('Earnings & Payments'), findsOneWidget);
    expect(find.text('Instant UPI Payouts'), findsOneWidget);

    // Verify Stat Cards
    expect(find.text('Total Earned'), findsOneWidget);
    expect(find.text('Deliveries Paid'), findsOneWidget);
    expect(find.text('Avg. per Delivery'), findsOneWidget);
    expect(find.text('Settlement Status'), findsOneWidget);

    // Verify UPI Payout VPA
    expect(find.textContaining('Payout VPA:'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Auto-Payout'), findsOneWidget);

    // Verify Payment Confirmations list
    expect(find.textContaining('Payment Confirmations'), findsOneWidget);
    expect(find.text('Rice & Dal Meal Packets'), findsOneWidget);
    expect(find.text('Biryani Special Portions'), findsOneWidget);

    // Verify card buttons
    expect(find.text('View Payment Details & Confirmation'), findsWidgets);
  });

  testWidgets('VolunteerDashboard displays Payments tab in bottom navigation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VolunteerDashboard(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Payments tab is present in bottom navigation
    expect(find.text('Payments'), findsOneWidget);

    // Tap on Payments tab
    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();

    // Verify Payments page content appears
    expect(find.text('Earnings & Payments'), findsOneWidget);
    expect(find.text('Instant UPI Payouts'), findsOneWidget);
  });
}
