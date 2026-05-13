import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/file_manager.dart';
import '../../../../core/utils/youtube_extractor.dart';
import '../../../../injection_container.dart' as di;

import '../../../downloader/presentation/bloc/downloader_bloc.dart';
import '../../../downloader/presentation/widgets/quality_bottom_sheet.dart';

class BrowserPage extends StatefulWidget {
  final void Function(int) onTabSwitch;

  const BrowserPage({super.key, required this.onTabSwitch});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  final _urlBarController = TextEditingController();

  double _loadingProgress = 0;
  bool _isLoading = false;
  String _currentUrl = '';
  bool _adBlockEnabled = true;
  bool _isFetchingStreams = false;

  /// Mobile User-Agent (iPhone Safari) to force mobile site layouts.
  static const _mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'Version/16.6 Mobile/15E148 Safari/604.1';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.kDeepBg)
      ..setUserAgent(_mobileUserAgent)
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
              _urlBarController.text = _isStartPage(url) ? '' : url;
              _isLoading = true;
            });
          }
        },
        onPageFinished: (url) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          if (_adBlockEnabled && !_isStartPage(url)) {
            _injectAdBlocker();
          }
        },
        onNavigationRequest: (request) {
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse('about:blank'));
  }

  bool _isStartPage(String url) {
    return url.isEmpty || url == 'about:blank';
  }

  void _injectAdBlocker() {
    const js = '''
      (function() {
        const adSelectors = [
          'iframe[src*="doubleclick"]',
          'iframe[src*="googlesyndication"]',
          'div[class*="ad-"]',
          'div[id*="ad-"]',
          'div[class*="banner"]',
          '[id*="google_ads"]',
          '.ad-container',
          '#ad-container',
          'ins.adsbygoogle'
        ];
        adSelectors.forEach(sel => {
          document.querySelectorAll(sel).forEach(el => el.remove());
        });
      })();
    ''';
    _controller.runJavaScript(js);
  }

  @override
  void dispose() {
    _urlBarController.dispose();
    super.dispose();
  }

  void _navigateTo(String input) {
    var url = input.trim();
    if (url.isEmpty) {
      _loadStartPage();
      return;
    }

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

  void _loadStartPage() {
    _controller.loadRequest(Uri.parse('about:blank'));
    if (mounted) {
      setState(() {
        _currentUrl = 'about:blank';
        _urlBarController.clear();
      });
    }
  }

  // ────────────────────────────────────────────────────────────
  //  Download Logic (CRITICAL)
  // ────────────────────────────────────────────────────────────

  Future<void> _onDownloadPressed() async {
    final url = _currentUrl;
    if (_isStartPage(url)) return;

    // Check if this is a YouTube URL
    if (YouTubeExtractor.isYouTubeUrl(url)) {
      await _handleYouTubeDownload(url);
    } else {
      // Direct file download — dispatch immediately, no tab switch
      context.read<DownloaderBloc>().add(StartDownloadEvent(url: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.kSurface,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Download started — check the Downloads tab',
              style: TextStyle(color: AppTheme.neonCyan, fontSize: 13),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleYouTubeDownload(String url) async {
    if (_isFetchingStreams) return;

    setState(() => _isFetchingStreams = true);

    try {
      final extractor = di.sl<YouTubeExtractor>();
      final streams = await extractor.extractStreams(url);

      if (!mounted) return;

      if (streams.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.kSurface,
            content: Text(
              'No downloadable streams found',
              style: TextStyle(color: AppTheme.kErrorRed, fontSize: 13),
            ),
          ),
        );
        return;
      }

      // Show the quality selection bottom sheet
      final selected = await showModalBottomSheet<StreamOption>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => QualityBottomSheet(streams: streams),
      );

      if (selected == null || !mounted) return;

      // Build metadata for the download
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

      // Dispatch download — NO tab switch
      context.read<DownloaderBloc>().add(
            StartDownloadEvent(url: selected.url, metadata: metadata),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.kSurface,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Downloading: ${selected.title}',
              style: const TextStyle(color: AppTheme.neonCyan, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.kSurface,
            content: Text(
              'Failed to fetch streams: ${e.toString().substring(0, (e.toString().length).clamp(0, 80))}',
              style: const TextStyle(color: AppTheme.kErrorRed, fontSize: 13),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingStreams = false);
      }
    }
  }

  // ────────────────────────────────────────────────────────────
  //  Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isStartPage = _isStartPage(_currentUrl);

    return Scaffold(
      backgroundColor: AppTheme.kDeepBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
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
                  if (isStartPage) _buildStartPage(),
                  if (_isFetchingStreams) _buildFetchingOverlay(),
                ],
              ),
            ),
            _buildBottomBar(isStartPage),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Top Bar — Clean, URL only
  // ────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.only(top: 6, left: 12, right: 12, bottom: 6),
      color: AppTheme.kDeepBg,
      child: Row(
        children: [
          // URL field
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.kSurface,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: AppTheme.neonCyan.withAlpha(30)),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 14),
                    child: Icon(Icons.search_rounded,
                        color: AppTheme.kTextDim, size: 18),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _urlBarController,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13.5, letterSpacing: 0.2),
                      decoration: const InputDecoration(
                        hintText: 'Search or enter URL…',
                        hintStyle:
                            TextStyle(color: AppTheme.kTextDim, fontSize: 13),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.go,
                      onSubmitted: _navigateTo,
                    ),
                  ),
                  // Ad Blocker Toggle
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() => _adBlockEnabled = !_adBlockEnabled);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.shield_rounded,
                        color: _adBlockEnabled
                            ? AppTheme.neonCyan
                            : AppTheme.kTextDim,
                        size: 18,
                      ),
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

  // ────────────────────────────────────────────────────────────
  //  Bottom Bar — Unified with all controls + download
  // ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(bool isStartPage) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.kSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: Navigation icons ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BottomNavIcon(
                icon: Icons.arrow_back_ios_rounded,
                label: 'Back',
                onTap: () => _controller.goBack(),
              ),
              _BottomNavIcon(
                icon: Icons.arrow_forward_ios_rounded,
                label: 'Forward',
                onTap: () => _controller.goForward(),
              ),
              _BottomNavIcon(
                icon: Icons.home_rounded,
                label: 'Home',
                onTap: _loadStartPage,
              ),
              _BottomNavIcon(
                icon: _isLoading ? Icons.close_rounded : Icons.refresh_rounded,
                label: _isLoading ? 'Stop' : 'Reload',
                onTap: () => _isLoading
                    ? _controller.loadRequest(Uri.parse('about:blank'))
                    : _controller.reload(),
              ),
              _BottomNavIcon(
                icon: Icons.history_rounded,
                label: 'History',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    backgroundColor: AppTheme.kSurface,
                    behavior: SnackBarBehavior.floating,
                    content: Text('Coming soon',
                        style: TextStyle(
                            color: AppTheme.neonCyan, fontSize: 13)),
                  ));
                },
              ),
              _BottomNavIcon(
                icon: Icons.bookmark_border_rounded,
                label: 'Bookmarks',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    backgroundColor: AppTheme.kSurface,
                    behavior: SnackBarBehavior.floating,
                    content: Text('Coming soon',
                        style: TextStyle(
                            color: AppTheme.neonCyan, fontSize: 13)),
                  ));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Row 2: Download button ──
          SizedBox(
            width: double.infinity,
            height: 46,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(23),
                gradient: isStartPage
                    ? const LinearGradient(
                        colors: [Color(0x1AFFFFFF), Color(0x1AFFFFFF)])
                    : const LinearGradient(
                        colors: [AppTheme.neonPurple, AppTheme.neonCyan]),
                boxShadow: isStartPage
                    ? []
                    : [
                        BoxShadow(
                          color: AppTheme.neonCyan.withAlpha(60),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ElevatedButton.icon(
                onPressed: isStartPage || _isFetchingStreams
                    ? null
                    : _onDownloadPressed,
                icon: Icon(
                  _isFetchingStreams
                      ? Icons.hourglass_top_rounded
                      : Icons.download_rounded,
                  size: 20,
                  color: isStartPage ? Colors.white38 : Colors.white,
                ),
                label: Text(
                  _isFetchingStreams ? 'Fetching…' : 'Download',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isStartPage ? Colors.white38 : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledForegroundColor: Colors.white38,
                  disabledBackgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Fetching Overlay
  // ────────────────────────────────────────────────────────────

  Widget _buildFetchingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: AppTheme.kSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonCyan.withAlpha(30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(
                      AppTheme.neonCyan.withAlpha(200)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Fetching available qualities…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This may take a few seconds',
                style: TextStyle(color: AppTheme.kTextDim, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Start Page
  // ────────────────────────────────────────────────────────────

  Widget _buildStartPage() {
    return Container(
      color: AppTheme.kDeepBg,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppTheme.neonPurple, AppTheme.neonCyan],
            ).createShader(rect),
            child: const Icon(Icons.download_rounded,
                color: Colors.white, size: 64),
          ),
          const SizedBox(height: 16),
          const Text(
            'MunDown Browser',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Browse, find, and download media',
            style: TextStyle(color: AppTheme.kTextDim, fontSize: 14),
          ),
          const SizedBox(height: 32),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.kSurface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppTheme.neonCyan.withAlpha(60)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonCyan.withAlpha(15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search the web or type a URL...',
                hintStyle: TextStyle(color: AppTheme.kTextDim, fontSize: 15),
                prefixIcon:
                    Icon(Icons.search_rounded, color: AppTheme.neonCyan),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textInputAction: TextInputAction.go,
              onSubmitted: _navigateTo,
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShortcutTile(
                icon: Icons.play_circle_fill_rounded,
                label: 'YouTube',
                color: Colors.redAccent,
                onTap: () => _navigateTo('https://m.youtube.com'),
              ),
              _ShortcutTile(
                icon: Icons.music_note_rounded,
                label: 'TikTok',
                color: Colors.white,
                onTap: () => _navigateTo('https://www.tiktok.com'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShortcutTile(
                icon: Icons.camera_alt_rounded,
                label: 'Instagram',
                color: Colors.pinkAccent,
                onTap: () => _navigateTo('https://www.instagram.com'),
              ),
              _ShortcutTile(
                icon: Icons.cloud_rounded,
                label: 'SoundCloud',
                color: Colors.orangeAccent,
                onTap: () => _navigateTo('https://m.soundcloud.com'),
              ),
            ],
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Bottom Nav Icon Button
// ──────────────────────────────────────────────────────────────

class _BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomNavIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.kTextDim,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Shortcut Tile
// ──────────────────────────────────────────────────────────────

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.kSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
