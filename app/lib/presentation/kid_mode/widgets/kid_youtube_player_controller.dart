import 'dart:async';

abstract class KidYoutubePlayerBridge {
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(double seconds);
}

class KidYoutubePlayerController {
  KidYoutubePlayerBridge? _bridge;
  double _currentSeconds = 0;

  double get currentSeconds => _currentSeconds;

  void attach(KidYoutubePlayerBridge bridge) {
    _bridge = bridge;
  }

  void detach(KidYoutubePlayerBridge bridge) {
    if (identical(_bridge, bridge)) {
      _bridge = null;
    }
  }

  void updateCurrentSeconds(double seconds) {
    _currentSeconds = seconds;
  }

  Future<void> play() async {
    await _bridge?.play();
  }

  Future<void> pause() async {
    await _bridge?.pause();
  }

  Future<void> seekBy(double deltaSeconds) async {
    final target = (_currentSeconds + deltaSeconds)
        .clamp(0, double.infinity)
        .toDouble();
    await seekTo(target);
  }

  Future<void> seekTo(double seconds) async {
    _currentSeconds = seconds;
    await _bridge?.seekTo(seconds);
  }
}
