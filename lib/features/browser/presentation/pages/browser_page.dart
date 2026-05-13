import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/themes/app_theme.dart';

import '../../../downloader/presentation/bloc/downloader_bloc.dart';

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
      ..setUserAgent(
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
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
          if (url.contains('youtube.com')) {
            _injectYouTubeTweaks();
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

  void _injectYouTubeTweaks() {
    const js = '''
      (function() {
        const banner = document.getElementById('app-banner');
        if (banner) banner.remove();
        const smartBanner = document.querySelector('.smart-banner');
        if (smartBanner) smartBanner.remove();
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

  void _onDownloadPressed() {
    final url = _currentUrl;
    if (_isStartPage(url)) return;

    // Dispatch to DownloaderBloc
    context.read<DownloaderBloc>().add(StartDownloadEvent(url: url));

    // Switch to Downloads Tab
    widget.onTabSwitch(1);
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
  //  Top Bar
  // ────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 8),
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
          // Home
          _NavButton(
            icon: Icons.home_rounded,
            onTap: _loadStartPage,
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlBarController,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13.5, letterSpacing: 0.2),
                      decoration: const InputDecoration(
                        hintText: 'Search or enter URL…',
                        hintStyle: TextStyle(color: AppTheme.kTextDim, fontSize: 13),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        _adBlockEnabled ? Icons.security_rounded : Icons.security_rounded,
                        color: _adBlockEnabled ? AppTheme.neonCyan : AppTheme.kTextDim,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Reload
          _NavButton(
            icon: _isLoading ? Icons.close_rounded : Icons.refresh_rounded,
            onTap: () => _isLoading ? null : _controller.reload(),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Bottom Bar
  // ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(bool isStartPage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.kSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded, color: AppTheme.kTextDim),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                backgroundColor: AppTheme.kSurface,
                content: Text('Coming soon', style: TextStyle(color: AppTheme.neonCyan, fontSize: 13)),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppTheme.kTextDim),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                backgroundColor: AppTheme.kSurface,
                content: Text('Coming soon', style: TextStyle(color: AppTheme.neonCyan, fontSize: 13)),
              ));
            },
          ),
          const Spacer(),
          SizedBox(
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: isStartPage
                    ? LinearGradient(colors: [Colors.white10, Colors.white10])
                    : const LinearGradient(colors: [AppTheme.neonPurple, AppTheme.neonCyan]),
                boxShadow: isStartPage
                    ? []
                    : [
                        BoxShadow(
                          color: AppTheme.neonCyan.withAlpha(80),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ElevatedButton.icon(
                onPressed: isStartPage ? null : _onDownloadPressed,
                icon: Icon(
                  Icons.download_rounded,
                  size: 20,
                  color: isStartPage ? Colors.white38 : Colors.white,
                ),
                label: Text(
                  'Download',
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
                    borderRadius: BorderRadius.circular(22),
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
          Icon(Icons.download_rounded, color: AppTheme.neonCyan, size: 64),
          const SizedBox(height: 16),
          const Text(
            'MunDown Browser',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
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
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.neonCyan),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                onTap: () => _navigateTo('https://www.youtube.com'),
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
                onTap: () => _navigateTo('https://www.soundcloud.com'),
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
//  Small Nav Button
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
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: Colors.white70, size: 22),
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
