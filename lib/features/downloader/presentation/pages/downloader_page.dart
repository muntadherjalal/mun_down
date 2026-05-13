import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/file_manager.dart';
import '../../../../core/utils/youtube_extractor.dart';
import '../../../../core/widgets/neon_arc_painter.dart';
import '../../../../injection_container.dart';
import '../../../files/presentation/pages/files_page.dart';
import '../../domain/entities/download_entity.dart';
import '../bloc/downloader_bloc.dart';
import '../widgets/quality_bottom_sheet.dart';

/// ─────────────────────────────────────────────────────────────
///  Downloader Page (Combined Input & List)
/// ─────────────────────────────────────────────────────────────
class DownloaderPage extends StatefulWidget {
  const DownloaderPage({super.key});

  @override
  State<DownloaderPage> createState() => _DownloaderPageState();
}

class _DownloaderPageState extends State<DownloaderPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _urlController = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _pulseController;
  bool _extracting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _autoPasteFromClipboard();
  }

  Future<void> _autoPasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.contains('http')) {
        _urlController.text = data.text!.trim();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  bool _isValidUrl(String url) {
    return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }

  Future<void> _onDownloadPressed() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !_isValidUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.kSurface,
          content: Text('Please enter a valid URL',
              style: TextStyle(color: AppTheme.kErrorRed, fontSize: 13)),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    if (YouTubeExtractor.isYouTubeUrl(url)) {
      await _showYouTubeQualitySelector(url);
    } else {
      _startDirectDownload(url);
    }
  }

  Future<void> _showYouTubeQualitySelector(String url) async {
    setState(() => _extracting = true);
    try {
      final extractor = sl<YouTubeExtractor>();
      final streams = await extractor.extractStreams(url);

      if (!mounted) return;
      setState(() => _extracting = false);

      if (streams.isEmpty) {
        _startDirectDownload(url);
        return;
      }

      final selected = await showModalBottomSheet<StreamOption>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => QualityBottomSheet(streams: streams),
      );

      if (selected != null && mounted) {
        final metadata = DownloadMetadata(
          title: selected.title,
          thumbnailUrl: selected.thumbnailUrl,
          author: selected.author,
          duration: selected.duration,
          sourceUrl: url,
          downloadedAt: DateTime.now(),
          fileSizeBytes: selected.sizeBytes ?? 0,
          format: selected.format,
          quality: selected.quality,
        );
        _startDirectDownload(selected.url, metadata: metadata);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _extracting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.kSurface,
          content: Text('Extraction failed: $e',
              style: const TextStyle(color: AppTheme.kErrorRed, fontSize: 13)),
        ));
        _startDirectDownload(url);
      }
    }
  }

  void _startDirectDownload(String url, {DownloadMetadata? metadata}) {
    context.read<DownloaderBloc>().add(
          StartDownloadEvent(url: url, metadata: metadata),
        );
  }

  void _onRetry() {
    context.read<DownloaderBloc>().add(const ResetDownloaderEvent());
  }

  void _onNewDownload() {
    _urlController.clear();
    context.read<DownloaderBloc>().add(const ResetDownloaderEvent());
  }

  // ────────────────────────────────────────────────────────────
  //  Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.kDeepBg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    const SizedBox(height: 16),
                    _buildUrlInput(),
                    const SizedBox(height: 16),
                    _buildDownloadButton(),
                    const SizedBox(height: 32),
                    const Text(
                      'ACTIVE DOWNLOAD',
                      style: TextStyle(
                        color: AppTheme.neonCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStateArea(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  App Bar
  // ────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppTheme.neonPurple, AppTheme.neonCyan],
            ).createShader(rect),
            child: const Icon(Icons.downloading_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 10),
          const Text(
            'Downloads',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  URL Input Field
  // ────────────────────────────────────────────────────────────

  Widget _buildUrlInput() {
    return BlocBuilder<DownloaderBloc, DownloaderState>(
      buildWhen: (prev, curr) =>
          curr is DownloaderInitialState || prev is! DownloaderInitialState,
      builder: (context, state) {
        final isActive = state is DownloaderInitialState && !_extracting;
        return AnimatedOpacity(
          opacity: isActive ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.neonCyan.withAlpha(60),
                width: 1.2,
              ),
              color: AppTheme.kSurface,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonCyan.withAlpha(18),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _urlController,
              focusNode: _focusNode,
              enabled: isActive,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
              decoration: InputDecoration(
                hintText: 'Paste a video or audio URL…',
                hintStyle:
                    const TextStyle(color: AppTheme.kTextDim, fontSize: 14),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 12),
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [AppTheme.neonPurple, AppTheme.neonCyan],
                    ).createShader(rect),
                    child: const Icon(Icons.link_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 50, minHeight: 48),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _urlController,
                  builder: (_, value, _) {
                    if (value.text.isEmpty || !isActive) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppTheme.kTextDim, size: 20),
                      onPressed: _urlController.clear,
                    );
                  },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onSubmitted: (_) => _onDownloadPressed(),
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Download Button
  // ────────────────────────────────────────────────────────────

  Widget _buildDownloadButton() {
    return BlocBuilder<DownloaderBloc, DownloaderState>(
      builder: (context, state) {
        final isIdle = state is DownloaderInitialState && !_extracting;
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: AnimatedOpacity(
            opacity: isIdle ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 300),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [AppTheme.neonPurple, AppTheme.neonCyan],
                ),
                boxShadow: isIdle
                    ? [
                        BoxShadow(
                          color: AppTheme.neonPurple.withAlpha(80),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: ElevatedButton.icon(
                onPressed: isIdle ? _onDownloadPressed : null,
                icon: _extracting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 22),
                label: Text(
                  _extracting ? 'Extracting…' : 'Download',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  //  State-driven content area
  // ────────────────────────────────────────────────────────────

  Widget _buildStateArea() {
    return BlocConsumer<DownloaderBloc, DownloaderState>(
      listenWhen: (prev, curr) => curr is DownloaderCompletedState,
      listener: (context, state) {
        // Signal the Files tab to rescan its directory.
        FilesPage.refreshNotifier.value++;
      },
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: switch (state) {
            DownloaderInitialState() => _buildIdleHint(),
            DownloaderFetchingState() => _buildFetchingIndicator(),
            DownloaderProgressState(entity: final e) =>
              _buildProgressRing(e),
            DownloaderCompletedState(entity: final e) =>
              _buildCompletedCard(e),
            DownloaderFailedState(message: final msg) =>
              _buildErrorCard(msg),
          },
        );
      },
    );
  }

  // ── Idle ────────────────────────────────────────────────────

  Widget _buildIdleHint() {
    return Container(
      key: const ValueKey('idle'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppTheme.kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, color: AppTheme.kTextDim.withAlpha(50), size: 48),
          const SizedBox(height: 12),
          Text(
            'No active downloads',
            style: TextStyle(
              color: AppTheme.kTextDim.withAlpha(150),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Fetching ────────────────────────────────────────────────

  Widget _buildFetchingIndicator() {
    return Container(
      key: const ValueKey('fetching'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              minHeight: 5,
              backgroundColor: AppTheme.kDeepBg,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Resolving URL…',
            style: TextStyle(
              color: AppTheme.neonCyan.withAlpha(200),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress Ring ───────────────────────────────────────────

  Widget _buildProgressRing(DownloadEntity entity) {
    final pct = (entity.progress * 100).round();
    return Container(
      key: const ValueKey('progress'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Track
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 8,
                    color: AppTheme.kDeepBg,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Neon arc
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: entity.progress),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (_, value, _) {
                      return CustomPaint(
                        painter: NeonArcPainter(
                          progress: value,
                          neonColor: AppTheme.neonCyan,
                          glowColor: AppTheme.neonCyan.withAlpha(60),
                        ),
                      );
                    },
                  ),
                ),
                // Percentage text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [AppTheme.neonPurple, AppTheme.neonCyan],
                      ).createShader(rect),
                      child: const Text(
                        'downloading',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // File name
          if (entity.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.kGlassWhite,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file_rounded,
                        color: AppTheme.neonCyan, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        entity.title,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Completed ───────────────────────────────────────────────

  Widget _buildCompletedCard(DownloadEntity entity) {
    return Container(
      key: const ValueKey('completed'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.kSurface,
        border: Border.all(color: const Color(0xFF2ECC71).withAlpha(50)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2ECC71).withAlpha(80),
                  blurRadius: 20,
                ),
              ],
            ),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Download Complete',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (entity.title.isNotEmpty)
            Text(
              entity.title,
              style: const TextStyle(color: AppTheme.kTextDim, fontSize: 13),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _onNewDownload,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('New Download'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2ECC71),
                side: const BorderSide(color: Color(0xFF2ECC71), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Failed ──────────────────────────────────────────────────

  Widget _buildErrorCard(String message) {
    return Container(
      key: const ValueKey('failed'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.kSurface,
        border: Border.all(color: AppTheme.kErrorRed.withAlpha(50)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.kErrorRed.withAlpha(30),
              border: Border.all(color: AppTheme.kErrorRed.withAlpha(80)),
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: AppTheme.kErrorRed, size: 30),
          ),
          const SizedBox(height: 14),
          const Text(
            'Download Failed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: AppTheme.kErrorRed.withAlpha(200),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _onNewDownload,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Dismiss'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withAlpha(40)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.kErrorRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
