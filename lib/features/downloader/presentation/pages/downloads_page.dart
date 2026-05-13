
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neon_arc_painter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/youtube_extractor.dart';
import '../../../files/presentation/pages/files_page.dart';
import '../../domain/entities/download_entity.dart';
import '../bloc/downloader_bloc.dart';
import '../widgets/quality_bottom_sheet.dart';
import '../../../../injection_container.dart';


class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage>
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
        _startDirectDownload(selected.url, title: selected.title);
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

  void _startDirectDownload(String url, {String? title}) {
    context.read<DownloaderBloc>().add(StartDownloadEvent(url: url, title: title));
  }

  void _onRetry() =>
      context.read<DownloaderBloc>().add(const ResetDownloaderEvent());

  void _onNewDownload() {
    _urlController.clear();
    context.read<DownloaderBloc>().add(const ResetDownloaderEvent());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocListener<DownloaderBloc, DownloaderState>(
      listenWhen: (prev, curr) => curr is DownloaderCompletedState,
      listener: (_, state) {
        // Signal the Files tab to rescan its directory.
        FilesPage.refreshNotifier.value++;
      },
      child: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 24),
              _buildHeaderOrb(),
              const SizedBox(height: 28),
              _buildUrlInput(),
              const SizedBox(height: 18),
              _buildDownloadButton(),
              const SizedBox(height: 32),
              _buildStateArea(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header orb ──────────────────────────────────────────────
  Widget _buildHeaderOrb() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + _pulseController.value * 0.06;
        final glow = 8.0 + _pulseController.value * 16;
        return Center(
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.kNeonPurple, AppTheme.kNeonCyan]),
                boxShadow: [
                  BoxShadow(color: AppTheme.kNeonCyan.withAlpha(80), blurRadius: glow, spreadRadius: 2),
                  BoxShadow(color: AppTheme.kNeonPurple.withAlpha(60), blurRadius: glow * 1.4, spreadRadius: 1),
                ],
              ),
              child: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 38),
            ),
          ),
        );
      },
    );
  }

  // ── URL input ───────────────────────────────────────────────
  Widget _buildUrlInput() {
    return BlocBuilder<DownloaderBloc, DownloaderState>(
      buildWhen: (p, c) => c is DownloaderInitialState || p is! DownloaderInitialState,
      builder: (context, state) {
        final isActive = state is DownloaderInitialState && !_extracting;
        return AnimatedOpacity(
          opacity: isActive ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.kNeonCyan.withAlpha(60), width: 1.2),
              color: AppTheme.kSurface,
              boxShadow: [BoxShadow(color: AppTheme.kNeonCyan.withAlpha(18), blurRadius: 20, offset: const Offset(0, 4))],
            ),
            child: TextField(
              controller: _urlController,
              focusNode: _focusNode,
              enabled: isActive,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Paste a video or audio URL…',
                hintStyle: const TextStyle(color: AppTheme.kTextDim, fontSize: 14),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 12),
                  child: ShaderMask(
                    shaderCallback: (r) => const LinearGradient(colors: [AppTheme.kNeonPurple, AppTheme.kNeonCyan]).createShader(r),
                    child: const Icon(Icons.link_rounded, color: Colors.white, size: 22),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 48),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _urlController,
                  builder: (_, v, _) => v.text.isEmpty || !isActive
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppTheme.kTextDim, size: 20),
                          onPressed: _urlController.clear),
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

  // ── Download button ─────────────────────────────────────────
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
                gradient: const LinearGradient(colors: [AppTheme.kNeonPurple, Color(0xFF8B5CF6), AppTheme.kNeonCyan]),
                boxShadow: isIdle
                    ? [BoxShadow(color: AppTheme.kNeonPurple.withAlpha(80), blurRadius: 18, offset: const Offset(0, 6))]
                    : [],
              ),
              child: ElevatedButton.icon(
                onPressed: isIdle ? _onDownloadPressed : null,
                icon: _extracting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 22),
                label: Text(_extracting ? 'Extracting…' : 'Download',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── State area ──────────────────────────────────────────────
  Widget _buildStateArea() {
    return BlocBuilder<DownloaderBloc, DownloaderState>(
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: switch (state) {
            DownloaderInitialState() => _buildIdleHint(),
            DownloaderFetchingState() => _buildFetching(),
            DownloaderProgressState(entity: final e) => _buildProgress(e),
            DownloaderCompletedState(entity: final e) => _buildCompleted(e),
            DownloaderFailedState(message: final m) => _buildFailed(m),
          },
        );
      },
    );
  }

  Widget _buildIdleHint() => Padding(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.only(top: 8),
      child: Text('Enter a URL above and tap Download to begin.',
          style: TextStyle(color: Colors.white.withAlpha(90), fontSize: 13, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center));

  Widget _buildFetching() => Container(
      key: const ValueKey('fetching'),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
                minHeight: 5, backgroundColor: AppTheme.kSurface, valueColor: AlwaysStoppedAnimation(AppTheme.kNeonCyan))),
        const SizedBox(height: 16),
        Text('Resolving URL…', style: TextStyle(color: AppTheme.kNeonCyan.withAlpha(200), fontSize: 14, fontWeight: FontWeight.w500)),
      ]));

  Widget _buildProgress(DownloadEntity entity) {
    final pct = (entity.progress * 100).round();
    return Container(
      key: const ValueKey('progress'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(children: [
        SizedBox(
          width: 130, height: 130,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(child: CircularProgressIndicator(value: 1, strokeWidth: 8, color: AppTheme.kSurface.withAlpha(180), strokeCap: StrokeCap.round)),
            SizedBox.expand(child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: entity.progress), duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
              builder: (_, v, _) => CustomPaint(painter: NeonArcPainter(progress: v, neonColor: AppTheme.kNeonCyan, glowColor: AppTheme.kNeonCyan.withAlpha(60))))),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$pct%', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(colors: [AppTheme.kNeonPurple, AppTheme.kNeonCyan]).createShader(r),
                child: const Text('downloading', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1))),
            ]),
          ]),
        ),
        if (entity.title.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: AppTheme.kGlassWhite, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.insert_drive_file_rounded, color: AppTheme.kNeonCyan, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(entity.title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildCompleted(DownloadEntity entity) => Container(
      key: const ValueKey('done'),
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [const Color(0xFF1A3A2A), AppTheme.kSurface.withAlpha(200)]),
        border: Border.all(color: const Color(0xFF2ECC71).withAlpha(50)),
      ),
      child: Column(children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFF2ECC71), Color(0xFF27AE60)]),
          boxShadow: [BoxShadow(color: const Color(0xFF2ECC71).withAlpha(80), blurRadius: 20)]),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 32)),
        const SizedBox(height: 14),
        const Text('Download Complete', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        if (entity.title.isNotEmpty) ...[const SizedBox(height: 6), Text(entity.title, style: const TextStyle(color: AppTheme.kTextDim, fontSize: 13), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)],
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _onNewDownload, icon: const Icon(Icons.add_rounded, size: 20), label: const Text('New Download'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2ECC71), side: const BorderSide(color: Color(0xFF2ECC71), width: 1.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 13)))),
      ]));

  Widget _buildFailed(String msg) => Container(
      key: const ValueKey('fail'),
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [const Color(0xFF3A1A1A), AppTheme.kSurface.withAlpha(200)]),
        border: Border.all(color: AppTheme.kErrorRed.withAlpha(50)),
      ),
      child: Column(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.kErrorRed.withAlpha(30), border: Border.all(color: AppTheme.kErrorRed.withAlpha(80))),
          child: const Icon(Icons.error_outline_rounded, color: AppTheme.kErrorRed, size: 28)),
        const SizedBox(height: 12),
        const Text('Download Failed', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(msg, style: TextStyle(color: AppTheme.kErrorRed.withAlpha(200), fontSize: 12), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _onNewDownload, icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Back'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: BorderSide(color: Colors.white.withAlpha(40)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 13)))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(onPressed: _onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.kErrorRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 13)))),
        ]),
      ]));
}

