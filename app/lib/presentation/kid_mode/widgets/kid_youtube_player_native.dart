import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class KidYoutubePlayer extends StatelessWidget {
  final YoutubePlayerController? controller;
  final String videoId;
  final bool isShort;

  const KidYoutubePlayer({
    super.key,
    required this.controller,
    required this.videoId,
    required this.isShort,
  });

  @override
  Widget build(BuildContext context) {
    final playerController = controller;
    if (playerController == null) {
      return const SizedBox.expand();
    }
    return YoutubePlayer(
      controller: playerController,
      aspectRatio: isShort ? 9 / 16 : 16 / 9,
      backgroundColor: Colors.black,
    );
  }
}
