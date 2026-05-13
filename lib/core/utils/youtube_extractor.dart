import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Describes a single downloadable media stream.
class StreamOption {
  /// Human-readable label shown in the quality selector, e.g. "720p • mp4".
  final String label;

  /// Direct URL to the stream.
  final String url;

  /// Video title (used as the file name).
  final String title;

  /// Whether this is an audio-only stream.
  final bool isAudioOnly;

  /// File size in bytes (may be approximate or null).
  final int? sizeBytes;

  const StreamOption({
    required this.label,
    required this.url,
    required this.title,
    this.isAudioOnly = false,
    this.sizeBytes,
  });

  /// Returns a human-readable file size string.
  String get formattedSize {
    if (sizeBytes == null) return '';
    final mb = sizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Service that extracts available media streams from a YouTube URL.
///
/// Uses [youtube_explode_dart] under the hood. Callers should
/// [dispose] the instance when it is no longer needed.
class YouTubeExtractor {
  final YoutubeExplode _yt;

  YouTubeExtractor() : _yt = YoutubeExplode();

  /// Returns `true` if [url] looks like a valid YouTube URL.
  static bool isYouTubeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('youtube-nocookie.com');
  }

  /// Fetches the video title for the given YouTube [url].
  Future<String> getVideoTitle(String url) async {
    final video = await _yt.videos.get(url);
    return video.title;
  }

  /// Fetches all available [StreamOption]s for the given YouTube [url].
  ///
  /// Returns a list sorted by quality (highest first for video,
  /// highest bitrate first for audio).
  Future<List<StreamOption>> extractStreams(String url) async {
    final video = await _yt.videos.get(url);
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);
    final title = video.title;

    final options = <StreamOption>[];

    // ── Muxed streams (video + audio) ───────────────────────
    final muxed = manifest.muxed.toList()
      ..sort((a, b) =>
          b.videoResolution.height
              .compareTo(a.videoResolution.height));

    for (final s in muxed) {
      final quality = '${s.videoResolution.height}p';
      options.add(StreamOption(
        label: '$quality • ${s.container.name}',
        url: s.url.toString(),
        title: title,
        sizeBytes: s.size.totalBytes,
      ));
    }

    // ── Audio-only streams ──────────────────────────────────
    final audioOnly = manifest.audioOnly.toList()
      ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

    for (final s in audioOnly) {
      final kbps = (s.bitrate.bitsPerSecond / 1000).round();
      options.add(StreamOption(
        label: '${kbps}kbps • ${s.container.name} (audio)',
        url: s.url.toString(),
        title: title,
        isAudioOnly: true,
        sizeBytes: s.size.totalBytes,
      ));
    }

    return options;
  }

  /// Releases resources held by the underlying YouTube client.
  void dispose() {
    _yt.close();
  }
}
