import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_flow/widgets/app_drawer.dart';

void main() {
  testWidgets('Clicking CircleAvatar in AppDrawer opens Edit Profile & Organization card',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          drawer: AppDrawer(activeRole: 'Food Provider'),
          body: Center(child: Text('Dashboard Body')),
        ),
      ),
    );

    // Open drawer
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // Verify CircleAvatar is present
    final avatarFinder = find.byType(CircleAvatar);
    expect(avatarFinder, findsOneWidget);

    // Tap on CircleAvatar
    await tester.tap(avatarFinder);
    await tester.pumpAndSettle();

    // Verify the "Edit Profile & Organization" dialog card appears!
    expect(find.text('Edit Profile & Organization'), findsAtLeastNWidgets(1));
    expect(find.text('Organization / Entity Name *'), findsOneWidget);
    expect(find.text('Display Name / Authorized Representative *'), findsOneWidget);
    expect(find.text('Contact Phone / WhatsApp'), findsOneWidget);
    expect(find.text('Operating Location / Address'), findsOneWidget);
    expect(find.text('Detect GPS'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });
}
