import 'package:baby_monitor/presentation/common/widgets/resolved_thumbnail_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResolvedThumbnailImage', () {
    testWidgets('shows error widget for empty URL', (tester) async {
      const errorKey = Key('error');
      const placeholderKey = Key('placeholder');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResolvedThumbnailImage(
              thumbnailUrl: '',
              placeholder: Container(key: placeholderKey),
              errorWidget: Container(key: errorKey),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(errorKey), findsOneWidget);
      expect(find.byKey(placeholderKey), findsNothing);
    });

    testWidgets('shows placeholder initially for non-empty URL', (
      tester,
    ) async {
      const placeholderKey = Key('placeholder');
      const errorKey = Key('error');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResolvedThumbnailImage(
              thumbnailUrl: 'https://i.ytimg.com/vi/test12345aa/hqdefault.jpg',
              placeholder: Container(key: placeholderKey),
              errorWidget: Container(key: errorKey),
            ),
          ),
        ),
      );

      // On the first frame the placeholder should be visible (before
      // the async _resolve completes).
      expect(find.byKey(placeholderKey), findsOneWidget);

      // Pump enough time for all candidate precache timeout timers to
      // fire (5 s each × number of candidates) so none remain pending.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 6));
      }
    });
  });
}
