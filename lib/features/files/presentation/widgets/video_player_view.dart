import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// ─────────────────────────────────────────────────────────────
///  Design Tokens
/// ─────────────────────────────────────────────────────────────
const _kNeonCyan = Color(0xFF00CEC9);
const _kNeonPurple = Color(0xFF6C5CE7);
const _kDeepBg = Color(0xFF141422);

/// Full-screen video player with Chewie, styled to match the neon theme.
///
/// Call via:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => VideoPlayerView(filePath: '/path/to/file.mp4', title: 'My Video'),
/// ));
/// ```
class VideoPlayerView extends StatefulWidget {
  /// Absolute path to the local video file.
  final String filePath;

  /// Title shown in the app bar.
  final String title;

  const VideoPlayerView({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Allow landscape when video player is open.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _videoController = VideoPlayerController.file(File(widget.filePath));

    try {
      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: _kNeonCyan,
          handleColor: _kNeonPurple,
          backgroundColor: Colors.white12,
          bufferedColor: _kNeonPurple.withAlpha(60),
        ),
      );

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    // Restore portrait-only when leaving the player.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDeepBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(15),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 22),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.redAccent.withAlpha(180), size: 56),
            const SizedBox(height: 16),
            const Text(
              'Unable to play this file',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.filePath.split(Platform.pathSeparator).last,
              style: TextStyle(
                color: Colors.white.withAlpha(80),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_chewieController == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(
                  _kNeonCyan.withAlpha(200),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Preparing player…',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
