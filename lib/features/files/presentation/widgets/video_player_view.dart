import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/themes/app_theme.dart';
import '../../domain/entities/downloaded_file_info.dart';

/// Plays downloaded video or audio using media_kit (libmpv).
///
/// - Verifies the file exists before initializing.
/// - Waits for metadata (duration) before showing controls.
/// - Uses media_kit's modern built-in MaterialVideoControls.
class VideoPlayerView extends StatefulWidget {
  final DownloadedFileInfo file;

  const VideoPlayerView({super.key, required this.file});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  Player? _player;
  VideoController? _controller;

  bool _hasError = false;
  String _errorMessage = 'Unable to play this file';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _checkAndInitPlayer();
  }

  Future<void> _checkAndInitPlayer() async {
    // Check if file exists before initializing
    final file = File(widget.file.path);
    if (!file.existsSync()) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'File not found or deleted';
          _ready = false;
        });
      }
      return;
    }

    // Check if file is empty
    final length = await file.length();
    if (length == 0) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'File is empty';
          _ready = false;
        });
      }
      return;
    }

    // File exists and is not empty, initialize player
    await _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      // 2. Configure audio session for background playback
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // 3. Create player and controller
      _player = Player();
      _controller = VideoController(_player!);

      // 4. Open media
      await _player!.open(Media(widget.file.path));

      // 5. Wait until we have a valid duration (metadata loaded)
      await _player!.stream.duration.firstWhere(
        (d) => d.inMilliseconds > 0,
      );

      if (mounted) setState(() => _ready = true);
    } catch (e) {
      _setError(e.toString());
    }
  }

  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = msg;
      });
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.file.displayTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Icon(
            widget.file.isVideo
                ? Icons.videocam_rounded
                : Icons.audiotrack_rounded,
            color: widget.file.isVideo ? AppTheme.neonPurple : AppTheme.neonCyan,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(child: Center(child: _buildBody())),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent.withAlpha(180),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (!_ready || _controller == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor:
                  AlwaysStoppedAnimation(AppTheme.neonCyan.withAlpha(200)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Preparing player…',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      );
    }

    return widget.file.isVideo
        ? AspectRatio(
            aspectRatio: 16 / 9,
            child: Video(
              controller: _controller!,
              controls: AdaptiveVideoControls,
            ),
          )
        : SizedBox(
            height: 220,
            child: Video(
              controller: _controller!,
              controls: AdaptiveVideoControls,
            ),
          );
  }
}
