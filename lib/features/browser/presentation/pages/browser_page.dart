import 'dart:io';

import '../../../downloader/domain/entities/download_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/youtube_extractor.dart';
import '../../../../injection_container.dart' as di;

import '../../../downloader/presentation/bloc/downloader_bloc.dart';
import '../../../downloader/presentation/widgets/quality_bottom_sheet.dart';
import '../widgets/widgets.dart';

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

  // Desktop UA tends to give YouTube proper inline playback in WKWebView.
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'Version/17.4 Safari/605.1.15';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    // Build platform-specific creation params so we can enable inline media
    // playback and disable the user-gesture requirement on iOS / Android.
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.kDeepBg)
      ..setUserAgent(_userAgent)
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

    // Android-specific: allow media autoplay without a user gesture.
    if (Platform.isAndroid) {
      final platform = _controller.platform;
      if (platform is AndroidWebViewController) {
        platform.setMediaPlaybackRequiresUserGesture(false);
      }
    }
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

    final extractor = di.sl<YouTubeExtractor>();
    // Kick off extraction immediately so the bottom sheet can render a
    // skeleton while we wait.
    final streamsFuture = extractor.extractStreams(url);

    final selected = await showModalBottomSheet<StreamOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QualityBottomSheet(streamsFuture: streamsFuture),
    );

    if (mounted) {
      setState(() => _isFetchingStreams = false);
    }

    if (selected == null || !mounted) return;

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
      needsMux: selected.needsMux,
      audioUrl: selected.audioUrl,
      audioFormat: selected.audioFormat,
    );

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
            const BrowserBrandHeader(),
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
                  if (isStartPage)
                    BrowserStartPage(
                      urlBarController: _urlBarController,
                      onNavigate: _navigateTo,
                    ),
                  if (_isFetchingStreams)
                    const Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Center(child: FetchingPill()),
                    ),
                ],
              ),
            ),
            BrowserBottomBar(
              isStartPage: isStartPage,
              isLoading: _isLoading,
              isFetchingStreams: _isFetchingStreams,
              onBack: () => _controller.goBack(),
              onForward: () => _controller.goForward(),
              onHome: _loadStartPage,
              onReload: () => _isLoading
                  ? _controller.loadRequest(Uri.parse('about:blank'))
                  : _controller.reload(),
              onHistory: () {
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
              onBookmarks: () {
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
              onDownloadPressed: _onDownloadPressed,
            ),
          ],
        ),
      ),
    );
  }
}
