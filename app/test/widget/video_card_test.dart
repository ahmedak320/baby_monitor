import 'package:baby_monitor/presentation/common/widgets/resolved_thumbnail_image.dart';
import 'package:baby_monitor/presentation/common/widgets/video_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('VideoCard uses resolved thumbnail rendering', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VideoCard(
            title: 'Test video',
            thumbnailUrl: 'https://i.ytimg.com/vi/abc123/maxresdefault.jpg',
          ),
        ),
      ),
    );

    expect(find.byType(ResolvedThumbnailImage), findsOneWidget);
  });
}
