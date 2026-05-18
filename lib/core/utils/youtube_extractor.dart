import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Describes a single downloadable media stream.
class StreamOption {
  /// Human-readable label shown in the quality selector, e.g. "720p • mp4".
  final String label;

  /// Direct URL to the (video/muxed/audio) stream.
  final String url;

  /// Video title (used as the file name).
  final String title;

  /// Whether this is an audio-only stream.
  final bool isAudioOnly;

  /// File size in bytes (may be approximate or null).
  /// For [needsMux] options this is video + audio bytes.
  final int? sizeBytes;

  /// Video author
  final String? author;

  /// Video thumbnail URL
  final String? thumbnailUrl;

  /// Video duration
  final Duration? duration;

  /// Format (container name)
  final String format;

  /// Quality string (e.g. 1080p, 320kbps)
  final String quality;

  /// When `true`, [url] points to a video-only stream and the audio
  /// at [audioUrl] must be downloaded separately and muxed (ffmpeg).
  final bool needsMux;

  /// Audio-only URL paired with [url] for muxing. Only set when [needsMux].
  final String? audioUrl;

  /// Audio container name for the paired audio stream.
  final String? audioFormat;

  const StreamOption({
    required this.label,
    required this.url,
    required this.title,
    this.isAudioOnly = false,
    this.sizeBytes,
    this.author,
    this.thumbnailUrl,
    this.duration,
    required this.format,
    required this.quality,
    this.needsMux = false,
    this.audioUrl,
    this.audioFormat,
  });

  /// Returns a human-readable file size string.
  String get formattedSize {
    if (sizeBytes == null || sizeBytes! <= 0) return '';
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
  /// Returns a list sorted lowest -> highest for video,
  /// then audio-only options (highest bitrate first).
  Future<List<StreamOption>> extractStreams(String url) async {
    final video = await _yt.videos.get(url);
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);
    final title = video.title;
    final author = video.author;
    final duration = video.duration;
    final thumbnailUrl = video.thumbnails.highResUrl;

    // Pick the best audio-only stream (for muxing with video-only streams).
    final audioOnly = manifest.audioOnly.toList()
      ..sort((a, b) =>
          b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

    final bestAudio = audioOnly.isNotEmpty ? audioOnly.first : null;

    // Build a map of resolution -> best option (prefer muxed > videoOnly).
    final byHeight = <int, StreamOption>{};

    // Muxed (video+audio in one file). These typically only go up to 720p mp4
    // and are the easiest to download.
    for (final s in manifest.muxed) {
      final height = s.videoResolution.height;
      final quality = '${height}p';
      byHeight[height] = StreamOption(
        label: '$quality • ${s.container.name}',
        url: s.url.toString(),
        title: title,
        sizeBytes: s.size.totalBytes,
        author: author,
        duration: duration,
        thumbnailUrl: thumbnailUrl,
        format: s.container.name,
        quality: quality,
      );
    }

    // Video-only — gives us higher resolutions (1080p, 1440p, 2160p, ...).
    // We require a muxer step (ffmpeg) to combine with the best audio.
    // Prefer mp4 container for muxing simplicity.
    final videoOnlyByHeight = <int, dynamic>{};
    for (final s in manifest.videoOnly) {
      final height = s.videoResolution.height;
      final existing = videoOnlyByHeight[height];
      // Prefer mp4; otherwise highest bitrate.
      final isMp4 = s.container.name.toLowerCase() == 'mp4';
      final existingIsMp4 = existing != null &&
          (existing as dynamic).container.name.toLowerCase() == 'mp4';
      if (existing == null ||
          (isMp4 && !existingIsMp4) ||
          (isMp4 == existingIsMp4 &&
              s.bitrate.bitsPerSecond >
                  (existing as dynamic).bitrate.bitsPerSecond)) {
        videoOnlyByHeight[height] = s;
      }
    }

    videoOnlyByHeight.forEach((height, s) {
      if (byHeight.containsKey(height)) return; // muxed already covers this
      if (bestAudio == null) return; // can't mux without audio
      final quality = '${height}p';
      final combinedSize =
          s.size.totalBytes + (bestAudio.size.totalBytes);
      byHeight[height] = StreamOption(
        label: '$quality • ${s.container.name}',
        url: s.url.toString(),
        title: title,
        sizeBytes: combinedSize,
        author: author,
        duration: duration,
        thumbnailUrl: thumbnailUrl,
        format: s.container.name,
        quality: quality,
        needsMux: true,
        audioUrl: bestAudio.url.toString(),
        audioFormat: bestAudio.container.name,
      );
    });

    // Sort video options lowest -> highest by height.
    final videoOptions = byHeight.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final options = <StreamOption>[
      ...videoOptions.map((e) => e.value),
    ];

    // Audio-only streams, highest bitrate first.
    for (final s in audioOnly) {
      final kbps = (s.bitrate.bitsPerSecond / 1000).round();
      final quality = '${kbps}kbps';
      options.add(StreamOption(
        label: '$quality • ${s.container.name} (audio)',
        url: s.url.toString(),
        title: title,
        isAudioOnly: true,
        sizeBytes: s.size.totalBytes,
        author: author,
        duration: duration,
        thumbnailUrl: thumbnailUrl,
        format: s.container.name,
        quality: quality,
      ));
    }

    return options;
  }

  /// Releases resources held by the underlying YouTube client.
  void dispose() {
    _yt.close();
  }
}
