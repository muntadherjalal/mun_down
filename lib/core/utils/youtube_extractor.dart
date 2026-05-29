import 'package:equatable/equatable.dart';

/// Represents a single downloadable stream option (video or audio).
///
/// Used by [QualityBottomSheet] to display available quality choices.
class StreamOption extends Equatable {
  /// Human-readable label (e.g. "720p", "1080p", "128 kbps").
  final String label;

  /// Resolution or bitrate string shown in the UI (e.g. "720p").
  final String quality;

  /// Container format (e.g. "mp4", "webm").
  final String format;

  /// Human-readable file size string (e.g. "12.3 MB").
  final String formattedSize;

  /// Whether this is an audio-only stream.
  final bool isAudioOnly;

  /// Whether this stream requires video+audio muxing after download.
  final bool needsMux;

  /// Direct URL for the video stream.
  final String url;

  /// Paired audio URL when [needsMux] is true.
  final String? audioUrl;

  const StreamOption({
    required this.label,
    required this.quality,
    required this.format,
    this.formattedSize = '',
    this.isAudioOnly = false,
    this.needsMux = false,
    required this.url,
    this.audioUrl,
  });

  @override
  List<Object?> get props => [
        label,
        quality,
        format,
        formattedSize,
        isAudioOnly,
        needsMux,
        url,
        audioUrl,
      ];
}
