// Basic Flutter widget test for Charm AI

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:charm_ai/app.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: CharmApp(),
      ),
    );

    // Verify the app builds without errors
    expect(find.byType(CharmApp), findsOneWidget);
  });
}
