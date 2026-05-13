import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/file_manager.dart';

class MediaPlayerSheet extends StatefulWidget {
  final DownloadedFileInfo file;

  const MediaPlayerSheet({super.key, required this.file});

  @override
  State<MediaPlayerSheet> createState() => _MediaPlayerSheetState();
}

class _MediaPlayerSheetState extends State<MediaPlayerSheet> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _videoController = VideoPlayerController.file(File(widget.file.path));

    try {
      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: widget.file.isVideo,
        allowMuting: true,
        showControlsOnInitialize: true,
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
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.kDeepBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(
                  widget.file.isVideo ? Icons.videocam_rounded : Icons.audiotrack_rounded,
                  color: widget.file.isVideo ? AppTheme.neonPurple : AppTheme.neonCyan,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.file.displayTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          // Player
          Flexible(
            child: _buildBody(),
          ),
          // Add safe area at the bottom
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.all(32),
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
          ],
        ),
      );
    }

    if (_chewieController == null) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
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
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final aspectRatio = widget.file.isVideo
        ? _videoController.value.aspectRatio
        : 1.0; // Audio player can just take 1:1 or specific height

    Widget player = Chewie(controller: _chewieController!);

    if (widget.file.isVideo) {
      player = AspectRatio(
        aspectRatio: aspectRatio,
        child: player,
      );
    } else {
      // For audio, restrict height
      player = SizedBox(
        height: 200,
        child: player,
      );
    }

    return player;
  }
}
