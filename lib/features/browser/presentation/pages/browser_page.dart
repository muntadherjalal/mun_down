import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/file_manager.dart';
import '../../../../core/utils/youtube_extractor.dart';
import '../../../../injection_container.dart';
import '../../../downloader/presentation/bloc/downloader_bloc.dart';
import '../../../downloader/presentation/widgets/quality_bottom_sheet.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  final _urlBarController = TextEditingController();
  
  double _loadingProgress = 0;
  bool _isLoading = false;
  String _currentUrl = 'https://www.youtube.com';
  bool _extracting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _urlBarController.text = _currentUrl;
    _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.kDeepBg)
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _loadingProgress = progress / 100;
              _isLoading = progress < 100;
            });
          }
        },
        onPageStarted: (url) {
          if (mounted) {
            setState(() {
              _currentUrl = url;
              _urlBarController.text = url;
              _isLoading = true;
            });
          }
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
        onNavigationRequest: (request) {
          // ALWAYS navigate, do not let external apps open
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(_currentUrl));
  }

  @override
  void dispose() {
    _urlBarController.dispose();
    super.dispose();
  }

  void _navigateTo(String input) {
    var url = input.trim();
    if (url.isEmpty) return;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      } else {
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }

    _controller.loadRequest(Uri.parse(url));
    FocusScope.of(context).unfocus();
  }

  bool _isDownloadable(String url) {
    if (YouTubeExtractor.isYouTubeUrl(url)) return true;
    final ext = url.split('.').last.toLowerCase();
    return ['mp4', 'mp3', 'mkv', 'webm', 'wav', 'm4a', 'avi'].contains(ext);
  }

  Future<void> _onDownloadPressed() async {
    final url = _currentUrl;
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.kSurface,
        content: Text('Download started in background',
            style: TextStyle(color: AppTheme.neonCyan, fontSize: 13)),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final showFab = _isDownloadable(_currentUrl);

    return Scaffold(
      backgroundColor: AppTheme.kDeepBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildUrlBar(),
            if (_isLoading)
              ClipRRect(
                child: LinearProgressIndicator(
                  value: _loadingProgress,
                  minHeight: 2.5,
                  backgroundColor: AppTheme.kSurface,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_extracting)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppTheme.neonCyan),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: showFab && !_extracting
          ? FloatingActionButton.extended(
              onPressed: _onDownloadPressed,
              backgroundColor: AppTheme.kSurface,
              icon: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [AppTheme.neonPurple, AppTheme.neonCyan],
                ).createShader(rect),
                child: const Icon(Icons.download_rounded, color: Colors.white),
              ),
              label: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [AppTheme.neonPurple, AppTheme.neonCyan],
                ).createShader(rect),
                child: const Text(
                  'Download',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildUrlBar() {
    return Container(
      padding: const EdgeInsets.only(
        top: 8,
        left: 12,
        right: 12,
        bottom: 8,
      ),
      color: AppTheme.kDeepBg,
      child: Row(
        children: [
          // Back
          _NavButton(
            icon: Icons.arrow_back_ios_rounded,
            onTap: () => _controller.goBack(),
          ),
          // Forward
          _NavButton(
            icon: Icons.arrow_forward_ios_rounded,
            onTap: () => _controller.goForward(),
          ),
          const SizedBox(width: 6),
          // URL field
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.kSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.neonCyan.withAlpha(40)),
              ),
              child: TextField(
                controller: _urlBarController,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13.5, letterSpacing: 0.2),
                decoration: InputDecoration(
                  hintText: 'Search or enter URL…',
                  hintStyle: const TextStyle(color: AppTheme.kTextDim, fontSize: 13),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [AppTheme.neonPurple, AppTheme.neonCyan],
                      ).createShader(rect),
                      child: const Icon(Icons.public_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 38, minHeight: 38),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                textInputAction: TextInputAction.go,
                onSubmitted: _navigateTo,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Reload
          _NavButton(
            icon: _isLoading ? Icons.close_rounded : Icons.refresh_rounded,
            onTap: () => _isLoading ? null : _controller.reload(), // Note: no stopLoading exposed easily, so we just let it be
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Small nav button
// ──────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}
