import 'dart:io';

import 'package:audio_session/audio_session.dart'; // مكتبة التشغيل بالخلفية
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/file_manager.dart';

class VideoPlayerView extends StatefulWidget {
  final DownloadedFileInfo file;

  const VideoPlayerView({super.key, required this.file});

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
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      // 🚀 إعداد جلسة الصوت للعمل بالخلفية (Background Audio)
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      _videoController = VideoPlayerController.file(File(widget.file.path));
      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: widget.file.isVideo,
        allowedScreenSleep: false, // يمنع إغلاق الشاشة أثناء التشغيل
        allowMuting: true,
        showControlsOnInitialize: true,
        // إعدادات PiP مدعومة في بعض الأجهزة
        allowPlaybackSpeedChanging: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.neonCyan,
          handleColor: AppTheme.neonPurple,
          backgroundColor: Colors.white12,
          bufferedColor: AppTheme.neonPurple.withAlpha(60),
        ),
      );

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // خلفية سينمائية
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.file.displayTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
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
            color: widget.file.isVideo
                ? AppTheme.neonPurple
                : AppTheme.neonCyan,
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
            size: 56,
          ),
          const SizedBox(height: 16),
          const Text(
            'Unable to play this file',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (_chewieController == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                AppTheme.neonCyan.withAlpha(200),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Preparing player…',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      );
    }

    final aspectRatio = widget.file.isVideo
        ? _videoController.value.aspectRatio
        : 1.0;

    Widget player = Chewie(controller: _chewieController!);

    if (widget.file.isVideo) {
      player = AspectRatio(aspectRatio: aspectRatio, child: player);
    } else {
      player = SizedBox(height: 200, child: player);
    }

    return player;
  }
}
