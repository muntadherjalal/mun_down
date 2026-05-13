import 'package:flutter/material.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/youtube_extractor.dart';

/// A sleek bottom sheet that displays available YouTube stream qualities.
class QualityBottomSheet extends StatefulWidget {
  final List<StreamOption> streams;

  const QualityBottomSheet({super.key, required this.streams});

  @override
  State<QualityBottomSheet> createState() => _QualityBottomSheetState();
}

class _QualityBottomSheetState extends State<QualityBottomSheet> {
  StreamOption? _selectedStream;

  @override
  void initState() {
    super.initState();
    if (widget.streams.isNotEmpty) {
      // Default to highest video quality, or highest audio if no video
      final videos = widget.streams.where((s) => !s.isAudioOnly).toList();
      if (videos.isNotEmpty) {
        _selectedStream = videos.first;
      } else {
        _selectedStream = widget.streams.first;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate video and audio streams.
    final videoStreams = widget.streams.where((s) => !s.isAudioOnly).toList();
    // Sort video by size/quality (assuming they are already sorted by extractor, but just to be sure)
    
    var audioStreams = widget.streams.where((s) => s.isAudioOnly).toList();
    // Keep top 3 audio streams
    if (audioStreams.length > 3) {
      audioStreams = audioStreams.take(3).toList();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.kDeepBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
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
              // Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        colors: [AppTheme.neonPurple, AppTheme.neonCyan],
                      ).createShader(r),
                      child: const Icon(Icons.high_quality_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Select Quality',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              // List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    if (videoStreams.isNotEmpty) ...[
                      _sectionLabel('VIDEO'),
                      ...videoStreams.map((s) => _StreamTile(
                            stream: s,
                            icon: Icons.videocam_rounded,
                            accentColor: AppTheme.neonPurple,
                            isSelected: _selectedStream == s,
                            onTap: () => setState(() => _selectedStream = s),
                          )),
                    ],
                    if (audioStreams.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _sectionLabel('AUDIO ONLY'),
                      ...audioStreams.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final s = entry.value;
                        // Map index to High/Medium/Low
                        String audioLabel = 'High';
                        if (idx == 1) audioLabel = 'Medium';
                        if (idx == 2) audioLabel = 'Low';

                        return _StreamTile(
                          stream: s,
                          customLabel: '$audioLabel Quality (${s.quality})',
                          icon: Icons.audiotrack_rounded,
                          accentColor: AppTheme.neonCyan,
                          isSelected: _selectedStream == s,
                          onTap: () => setState(() => _selectedStream = s),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              // Download Button Fixed at Bottom
              _buildDownloadButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.neonCyan.withAlpha(180),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildDownloadButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), // Add bottom padding for SafeArea
      decoration: BoxDecoration(
        color: AppTheme.kDeepBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [AppTheme.neonPurple, AppTheme.neonCyan],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonPurple.withAlpha(80),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () {
              if (_selectedStream != null) {
                Navigator.pop(context, _selectedStream);
              }
            },
            icon: const Icon(Icons.download_rounded, size: 22),
            label: const Text(
              'Download',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamTile extends StatelessWidget {
  final StreamOption stream;
  final String? customLabel;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _StreamTile({
    required this.stream,
    this.customLabel,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withAlpha(20) : AppTheme.kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: accentColor.withAlpha(25),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customLabel ?? stream.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withAlpha(220),
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                        if (stream.formattedSize.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              stream.formattedSize,
                              style: const TextStyle(
                                  color: AppTheme.kTextDim, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: accentColor, size: 22)
                  else
                    const SizedBox(width: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
