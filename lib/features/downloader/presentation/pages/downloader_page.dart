
import 'package:flutter/material.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/neon_arc_painter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/download_entity.dart';
import '../bloc/downloader_bloc.dart';

/// ─────────────────────────────────────────────────────────────
///  Design Tokens  (derived from AppTheme palette)
/// ─────────────────────────────────────────────────────────────

/// ─────────────────────────────────────────────────────────────
///  Downloader Page
/// ─────────────────────────────────────────────────────────────
class DownloaderPage extends StatefulWidget {
  const DownloaderPage({super.key});

  @override
  State<DownloaderPage> createState() => _DownloaderPageState();
}

class _DownloaderPageState extends State<DownloaderPage>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _autoPasteFromClipboard();
  }

  /// Reads the clipboard; if it contains an HTTP URL, pre-fills the input.
  Future<void> _autoPasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.contains('http')) {
        _urlController.text = data.text!.trim();
      }
    } catch (_) {
      // Clipboard access may fail on some platforms — silently ignore.
    }
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

  void _onDownloadPressed() {
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
    context.read<DownloaderBloc>().add(StartDownloadEvent(url: url));
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
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildHeaderIllustration(),
                      const SizedBox(height: 32),
                      _buildUrlInput(),
                      const SizedBox(height: 20),
                      _buildDownloadButton(),
                      const SizedBox(height: 36),
                      _buildStateArea(),
                      const SizedBox(height: 24),
                    ],
                  ),
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

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppTheme.kDeepBg.withAlpha(230),
      surfaceTintColor: Colors.transparent,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppTheme.kNeonPurple, AppTheme.kNeonCyan],
            ).createShader(rect),
            child: const Icon(Icons.downloading_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 10),
          const Text(
            'MunDown',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Animated header graphic
  // ────────────────────────────────────────────────────────────

  Widget _buildHeaderIllustration() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + _pulseController.value * 0.06;
        final glow = 8.0 + _pulseController.value * 16;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.kNeonPurple, AppTheme.kNeonCyan],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.kNeonCyan.withAlpha(80),
                  blurRadius: glow,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppTheme.kNeonPurple.withAlpha(60),
                  blurRadius: glow * 1.4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.arrow_downward_rounded,
                color: Colors.white, size: 44),
          ),
        );
      },
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
        final isActive = state is DownloaderInitialState;
        return AnimatedOpacity(
          opacity: isActive ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.kNeonCyan.withAlpha(60),
                width: 1.2,
              ),
              color: AppTheme.kSurface,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.kNeonCyan.withAlpha(18),
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
                hintStyle: const TextStyle(color: AppTheme.kTextDim, fontSize: 14),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 12),
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [AppTheme.kNeonPurple, AppTheme.kNeonCyan],
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
        final isIdle = state is DownloaderInitialState;
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
                  colors: [AppTheme.kNeonPurple, Color(0xFF8B5CF6), AppTheme.kNeonCyan],
                ),
                boxShadow: isIdle
                    ? [
                        BoxShadow(
                          color: AppTheme.kNeonPurple.withAlpha(80),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: ElevatedButton.icon(
                onPressed: isIdle ? _onDownloadPressed : null,
                icon: const Icon(Icons.download_rounded, size: 22),
                label: const Text(
                  'Download',
                  style: TextStyle(
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
    return BlocBuilder<DownloaderBloc, DownloaderState>(
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
    return Padding(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'Enter a URL above and tap Download to begin.',
        style: TextStyle(
          color: Colors.white.withAlpha(90),
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ── Fetching ────────────────────────────────────────────────

  Widget _buildFetchingIndicator() {
    return Container(
      key: const ValueKey('fetching'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              minHeight: 5,
              backgroundColor: AppTheme.kSurface,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.kNeonCyan),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Resolving URL…',
            style: TextStyle(
              color: AppTheme.kNeonCyan.withAlpha(200),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                    color: AppTheme.kSurface.withAlpha(180),
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
                          neonColor: AppTheme.kNeonCyan,
                          glowColor: AppTheme.kNeonCyan.withAlpha(60),
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
                        colors: [AppTheme.kNeonPurple, AppTheme.kNeonCyan],
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.kGlassWhite,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.insert_drive_file_rounded,
                      color: AppTheme.kNeonCyan, size: 18),
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
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A3A2A),
            AppTheme.kSurface.withAlpha(200),
          ],
        ),
        border: Border.all(color: const Color(0xFF2ECC71).withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2ECC71).withAlpha(25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
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
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3A1A1A),
            AppTheme.kSurface.withAlpha(200),
          ],
        ),
        border: Border.all(color: AppTheme.kErrorRed.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.kErrorRed.withAlpha(20),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
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
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
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

// ──────────────────────────────────────────────────────────────
//  Custom Painter: Neon Arc for progress ring
// ──────────────────────────────────────────────────────────────

