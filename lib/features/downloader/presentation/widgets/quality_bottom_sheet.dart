import 'package:flutter/material.dart';

import '../../../../core/utils/youtube_extractor.dart';

const _kNeonCyan = Color(0xFF00CEC9);
const _kNeonPurple = Color(0xFF6C5CE7);
const _kSurface = Color(0xFF1E1E2C);
const _kDeepBg = Color(0xFF141422);
const _kTextDim = Color(0x99E0E0E0);

/// A sleek bottom sheet that displays available YouTube stream qualities.
class QualityBottomSheet extends StatelessWidget {
  final List<StreamOption> streams;

  const QualityBottomSheet({super.key, required this.streams});

  @override
  Widget build(BuildContext context) {
    // Separate video and audio streams.
    final videoStreams = streams.where((s) => !s.isAudioOnly).toList();
    final audioStreams = streams.where((s) => s.isAudioOnly).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _kDeepBg,
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
                        colors: [_kNeonPurple, _kNeonCyan],
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
                            accentColor: _kNeonPurple,
                            onTap: () => Navigator.pop(context, s),
                          )),
                    ],
                    if (audioStreams.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _sectionLabel('AUDIO ONLY'),
                      ...audioStreams.map((s) => _StreamTile(
                            stream: s,
                            icon: Icons.audiotrack_rounded,
                            accentColor: _kNeonCyan,
                            onTap: () => Navigator.pop(context, s),
                          )),
                    ],
                  ],
                ),
              ),
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
          color: _kNeonCyan.withAlpha(180),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _StreamTile extends StatelessWidget {
  final StreamOption stream;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _StreamTile({
    required this.stream,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        stream.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (stream.formattedSize.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            stream.formattedSize,
                            style: const TextStyle(
                                color: _kTextDim, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.download_rounded,
                    color: accentColor.withAlpha(160), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
