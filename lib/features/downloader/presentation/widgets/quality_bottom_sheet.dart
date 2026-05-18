import 'package:flutter/material.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/youtube_extractor.dart';

/// A sleek bottom sheet that displays available YouTube stream qualities.
///
/// The sheet renders immediately with a skeleton while [streamsFuture] is
/// pending, so the user never sees a blank screen waiting for "Fetching
/// qualities…". Once the future completes the real list is shown and the
/// Download button becomes enabled.
class QualityBottomSheet extends StatefulWidget {
  final Future<List<StreamOption>> streamsFuture;

  const QualityBottomSheet({super.key, required this.streamsFuture});

  @override
  State<QualityBottomSheet> createState() => _QualityBottomSheetState();
}

class _QualityBottomSheetState extends State<QualityBottomSheet> {
  StreamOption? _selectedStream;
  List<StreamOption>? _streams;
  Object? _error;

  @override
  void initState() {
    super.initState();
    widget.streamsFuture.then((streams) {
      if (!mounted) return;
      setState(() {
        _streams = streams;
        // Default to highest video quality available, else first audio.
        final videos = streams.where((s) => !s.isAudioOnly).toList();
        if (videos.isNotEmpty) {
          _selectedStream = videos.last; // highest (list is ascending)
        } else if (streams.isNotEmpty) {
          _selectedStream = streams.first;
        }
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
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
              _buildHandle(),
              _buildTitle(),
              const Divider(color: Colors.white10, height: 1),
              Expanded(child: _buildBody(scrollController)),
              _buildDownloadButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
          const Spacer(),
          if (_streams == null && _error == null)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to load qualities:\n${_error.toString()}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.kErrorRed, fontSize: 13),
          ),
        ),
      );
    }

    if (_streams == null) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _sectionLabel('VIDEO'),
          for (var i = 0; i < 4; i++) const _SkeletonTile(),
          const SizedBox(height: 12),
          _sectionLabel('AUDIO ONLY'),
          for (var i = 0; i < 2; i++) const _SkeletonTile(),
        ],
      );
    }

    final videoStreams = _streams!.where((s) => !s.isAudioOnly).toList();
    var audioStreams = _streams!.where((s) => s.isAudioOnly).toList();
    if (audioStreams.length > 3) audioStreams = audioStreams.take(3).toList();

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    final enabled = _selectedStream != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
            gradient: enabled
                ? const LinearGradient(
                    colors: [AppTheme.neonPurple, AppTheme.neonCyan],
                  )
                : null,
            color: enabled ? null : Colors.white12,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppTheme.neonPurple.withAlpha(80),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton.icon(
            onPressed: enabled
                ? () => Navigator.pop(context, _selectedStream)
                : null,
            icon: const Icon(Icons.download_rounded, size: 22),
            label: Text(
              _streams == null ? 'Fetching qualities…' : 'Download',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white54,
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

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.kSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withAlpha(220),
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        if (stream.formattedSize.isNotEmpty ||
                            stream.needsMux)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                if (stream.formattedSize.isNotEmpty)
                                  Text(
                                    stream.formattedSize,
                                    style: const TextStyle(
                                      color: AppTheme.kTextDim,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (stream.needsMux) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.neonCyan.withAlpha(40),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'HD merge',
                                      style: TextStyle(
                                        color: AppTheme.neonCyan,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded,
                        color: accentColor, size: 22)
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
