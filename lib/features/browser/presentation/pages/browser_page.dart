import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// ─────────────────────────────────────────────────────────────
///  Design Tokens
/// ─────────────────────────────────────────────────────────────
const _kNeonCyan = Color(0xFF00CEC9);
const _kNeonPurple = Color(0xFF6C5CE7);
const _kNeonGreen = Color(0xFF2ECC71);
const _kSurface = Color(0xFF1E1E2C);
const _kDeepBg = Color(0xFF141422);
const _kTextDim = Color(0x99E0E0E0);

/// ─────────────────────────────────────────────────────────────
///  Known ad / tracking domains
/// ─────────────────────────────────────────────────────────────
const _adDomains = <String>[
  'doubleclick.net',
  'googleadservices.com',
  'googlesyndication.com',
  'googleads.g.doubleclick.net',
  'adservice.google.com',
  'pagead2.googlesyndication.com',
  'ad.doubleclick.net',
  'ads.yahoo.com',
  'ads.twitter.com',
  'facebook.com/tr',
  'analytics.tiktok.com',
  'amazon-adsystem.com',
  'serving-sys.com',
  'adnxs.com',
  'adsrvr.org',
  'taboola.com',
  'outbrain.com',
  'moatads.com',
  'pubmatic.com',
  'rubiconproject.com',
  'criteo.com',
  'quantserve.com',
  'scorecardresearch.com',
  'smartadserver.com',
  'openx.net',
  'advertising.com',
  'admob.com',
];

/// In-app browser tab with ad-blocking and smart navigation.
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
  bool _adBlockEnabled = true;
  int _adsBlocked = 0;
  String _currentUrl = 'https://www.google.com';

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
      ..setBackgroundColor(_kDeepBg)
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
              _adsBlocked = 0; // Reset per-page counter.
            });
          }
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
        onNavigationRequest: (request) {
          if (_adBlockEnabled && _isAdUrl(request.url)) {
            if (mounted) setState(() => _adsBlocked++);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(_currentUrl));
  }

  /// Checks if a URL belongs to a known ad/tracking domain.
  bool _isAdUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return _adDomains.any((domain) => host.contains(domain));
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

  void _toggleAdBlock() {
    setState(() => _adBlockEnabled = !_adBlockEnabled);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _kSurface,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      content: Row(
        children: [
          Icon(
            _adBlockEnabled ? Icons.shield_rounded : Icons.shield_outlined,
            color: _adBlockEnabled ? _kNeonGreen : _kTextDim,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            _adBlockEnabled ? 'Ad-Blocker enabled' : 'Ad-Blocker disabled',
            style: TextStyle(
              color: _adBlockEnabled ? _kNeonGreen : _kTextDim,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ));
  }

  // ────────────────────────────────────────────────────────────
  //  Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _buildUrlBar(),
        if (_isLoading)
          ClipRRect(
            child: LinearProgressIndicator(
              value: _loadingProgress,
              minHeight: 2.5,
              backgroundColor: _kSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(_kNeonCyan),
            ),
          ),
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),
      ],
    );
  }

  Widget _buildUrlBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        bottom: 8,
      ),
      color: _kDeepBg,
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
                color: _kSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kNeonCyan.withAlpha(40)),
              ),
              child: TextField(
                controller: _urlBarController,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13.5, letterSpacing: 0.2),
                decoration: InputDecoration(
                  hintText: 'Search or enter URL…',
                  hintStyle: const TextStyle(color: _kTextDim, fontSize: 13),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [_kNeonPurple, _kNeonCyan],
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
          // Ad-Blocker shield toggle
          _ShieldButton(
            enabled: _adBlockEnabled,
            adsBlocked: _adsBlocked,
            onTap: _toggleAdBlock,
          ),
          const SizedBox(width: 2),
          // Reload
          _NavButton(
            icon: _isLoading ? Icons.close_rounded : Icons.refresh_rounded,
            onTap: () => _controller.reload(),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Shield Button (Ad-Blocker toggle)
// ──────────────────────────────────────────────────────────────

class _ShieldButton extends StatelessWidget {
  final bool enabled;
  final int adsBlocked;
  final VoidCallback onTap;

  const _ShieldButton({
    required this.enabled,
    required this.adsBlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: ShaderMask(
              shaderCallback: enabled
                  ? (rect) => const LinearGradient(
                        colors: [_kNeonGreen, _kNeonCyan],
                      ).createShader(rect)
                  : (rect) => LinearGradient(
                        colors: [
                          Colors.white.withAlpha(60),
                          Colors.white.withAlpha(60),
                        ],
                      ).createShader(rect),
              child: Icon(
                enabled ? Icons.shield_rounded : Icons.shield_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          // Badge: number of ads blocked on this page.
          if (enabled && adsBlocked > 0)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _kNeonGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kNeonGreen.withAlpha(120),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  adsBlocked > 99 ? '99+' : '$adsBlocked',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
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
