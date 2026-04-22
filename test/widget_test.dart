/// Smoke test — verifies the app widget tree renders without throwing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/app/app.dart';

void main() {
  testWidgets('App renders search placeholder without error',
      (WidgetTester tester) async {
    /// Wrap [App] in [ProviderScope] — required for Riverpod providers.
    await tester.pumpWidget(const ProviderScope(child: App()));

    /// Let go_router resolve the initial route.
    await tester.pumpAndSettle();

    /// Placeholder text confirms the search screen loaded.
    expect(find.text('Search Screen — coming soon'), findsOneWidget);
  });
}
