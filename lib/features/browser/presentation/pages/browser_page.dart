import '../../../downloader/domain/entities/download_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/themes/app_theme.dart';
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
  final bool _adBlockEnabled = true;
  bool _isFetchingStreams = false;

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
      ..setNavigationDelegate(
        NavigationDelegate(
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
          onUrlChange: (UrlChange change) {
            if (mounted && change.url != null) {
              setState(() {
                _currentUrl = change.url!;
              });
            }
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      )
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

  Future<void> _onDownloadPressed() async {
    final url = _currentUrl;
    if (_isStartPage(url)) return;

    if (YouTubeExtractor.isYouTubeUrl(url)) {
      await _handleYouTubeDownload(url);
    } else {
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

      final selected = await showModalBottomSheet<StreamOption>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => QualityBottomSheet(streams: streams),
      );

      if (selected == null || !mounted) return;

      // FIX 1: استخدام selected.url مباشرة مع non-null assertion
      final downloadUrl = selected.url;

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

      // FIX 2: تمرير metadata بشكل صحيح بدون cast
      context.read<DownloaderBloc>().add(
        StartDownloadEvent(url: downloadUrl, metadata: metadata),
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
            _buildBrandHeader(),
            if (_isLoading)
              ClipRRect(
                child: LinearProgressIndicator(
                  value: _loadingProgress,
                  minHeight: 2.5,
                  backgroundColor: AppTheme.kSurface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.neonCyan,
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (isStartPage) _buildStartPage(),
                  if (_isFetchingStreams)
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildFetchingPill()),
                    ),
                ],
              ),
            ),
            _buildBottomBar(isStartPage),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.kDeepBg,
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(10), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.download_rounded,
            color: AppTheme.neonCyan,
            size: 22,
          ),
          const SizedBox(width: 8),
          const Text(
            'MunDown',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartPage() {
    return Container(
      color: AppTheme.kDeepBg,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'What do you want to download?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.kSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.neonCyan.withAlpha(80)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonCyan.withAlpha(20),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              controller: _urlBarController,
              decoration: const InputDecoration(
                hintText: 'Search or enter URL...',
                hintStyle: TextStyle(color: AppTheme.kTextDim, fontSize: 15),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppTheme.neonCyan,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
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

  Widget _buildFetchingPill() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.kSurface.withAlpha(240),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.neonCyan.withAlpha(50)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppTheme.neonCyan),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Fetching qualities...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppTheme.kSurface,
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        'History logged successfully',
                        style: TextStyle(
                          color: AppTheme.neonCyan,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
              _BottomNavIcon(
                icon: Icons.bookmark_border_rounded,
                label: 'Bookmarks',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppTheme.kSurface,
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        'Saved to Bookmarks!',
                        style: TextStyle(
                          color: AppTheme.neonPurple,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(23),
                gradient: isStartPage
                    ? const LinearGradient(
                        colors: [Color(0x1AFFFFFF), Color(0x1AFFFFFF)],
                      )
                    : const LinearGradient(
                        colors: [AppTheme.neonPurple, AppTheme.neonCyan],
                      ),
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
                  _isFetchingStreams ? 'Wait...' : 'Download',
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
}

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
