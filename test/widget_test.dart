// This is a basic Flutter widget test for the AppBadge widget.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coach_money/presentation/widgets/app_badge.dart';

void main() {
  testWidgets('AppBadge renders label correctly', (WidgetTester tester) async {
    // Build AppBadge inside a MaterialApp.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppBadge(
            label: 'Test Badge',
            tone: 'blue',
          ),
        ),
      ),
    );

    // Verify that the AppBadge displays the text.
    expect(find.text('Test Badge'), findsOneWidget);
  });
}

