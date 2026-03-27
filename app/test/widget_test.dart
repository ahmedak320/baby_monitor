import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders a MaterialApp without crashing', (tester) async {
    // Minimal smoke test: verify a ProviderScope + MaterialApp can be pumped
    // without crashing. Full integration tests with Supabase are in Phase 6.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Baby Monitor')),
          ),
        ),
      ),
    );

    expect(find.text('Baby Monitor'), findsOneWidget);
  });

  testWidgets('ProviderScope wraps correctly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return const Scaffold(
                body: Center(child: Text('Provider test')),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Provider test'), findsOneWidget);
  });
}
