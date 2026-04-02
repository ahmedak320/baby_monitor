import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/presentation/kid_mode/widgets/kid_youtube_player_diagnostics.dart';

void main() {
  group('KidYoutubePlayerDiagnostics', () {
    test('ignores subresource web errors', () {
      final fatal =
          KidYoutubePlayerDiagnostics.shouldTreatWebResourceErrorAsFatal(
            isForMainFrame: false,
            description: 'net::ERR_ABORTED',
          );

      expect(fatal, isFalse);
    });

    test('treats main frame failures as fatal', () {
      final fatal =
          KidYoutubePlayerDiagnostics.shouldTreatWebResourceErrorAsFatal(
            isForMainFrame: true,
            description: 'net::ERR_CONNECTION_RESET',
          );

      expect(fatal, isTrue);
    });

    test('detects embed restrictions from page text', () {
      expect(
        KidYoutubePlayerDiagnostics.looksLikeEmbedRestrictedError(
          'Playback on other websites has been disabled',
        ),
        isTrue,
      );
    });
  });
}
