import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_flow/services/food_rescue_service.dart';
import 'package:food_flow/widgets/realtime_countdown_badge.dart';

void main() {
  testWidgets('RealtimeMealCountdownBadge displays ticking remaining time',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final safeUntil = now.add(const Duration(hours: 3, minutes: 45, seconds: 30));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RealtimeMealCountdownBadge(
            safeUntil: safeUntil,
            status: BatchStatus.available,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify countdown text is rendered
    expect(find.textContaining('left'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

    // Advance virtual clock by 2 seconds
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('left'), findsOneWidget);
  });

  testWidgets('RealtimeMealCountdownBadge displays Expired when time has passed',
      (WidgetTester tester) async {
    final pastTime = DateTime.now().subtract(const Duration(minutes: 5));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RealtimeMealCountdownBadge(
            safeUntil: pastTime,
            status: BatchStatus.available,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Expired'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('RealtimeMealCountdownBadge displays Rescued when batch is delivered',
      (WidgetTester tester) async {
    final futureTime = DateTime.now().add(const Duration(hours: 2));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RealtimeMealCountdownBadge(
            safeUntil: futureTime,
            status: BatchStatus.delivered,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Rescued'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
