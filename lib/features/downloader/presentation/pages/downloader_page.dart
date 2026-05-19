import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_theme.dart';
import '../../domain/entities/download_entity.dart';
import '../bloc/downloader_bloc.dart';

class DownloaderPage extends StatefulWidget {
  const DownloaderPage({super.key});
  @override
  State<DownloaderPage> createState() => _DownloaderPageState();
}

class _DownloaderPageState extends State<DownloaderPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppBar(),
            Expanded(
              child: BlocBuilder<DownloaderBloc, DownloaderState>(
                builder: (context, state) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _buildStateContent(context, state),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [AppTheme.neonPurple, AppTheme.neonCyan],
          ).createShader(rect),
          child: Icon(Icons.downloading_rounded, color: AppTheme.onSurface(context), size: 20),
        ),
        const SizedBox(width: 8),
        Text('Downloads', style: TextStyle(color: AppTheme.onSurface(context), fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 0.3)),
      ]),
    );
  }

  Widget _buildStateContent(BuildContext context, DownloaderState state) {
    if (state is DownloaderInitialState) return _buildEmptyState();
    if (state is DownloaderFetchingState) return _buildFetchingCard();
    if (state is DownloaderProgressState) return _buildProgressCard(context, state.entity);
    if (state is DownloaderPausedState) return _buildPausedCard(context, state.entity);
    if (state is DownloaderCompletedState) return _buildCompletedCard(context, state.entity);
    if (state is DownloaderFailedState) return _buildFailedCard(context, state.message);
    return const SizedBox.shrink();
  }

  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('empty'),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.download_rounded, color: AppTheme.dimText(context).withAlpha(80), size: 64),
        const SizedBox(height: 16),
        Text('No downloads yet', style: TextStyle(color: AppTheme.onSurface(context), fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Browse the web and tap Download to start', style: TextStyle(color: AppTheme.dimText(context).withAlpha(180), fontSize: 14)),
      ]),
    );
  }

  Widget _buildFetchingCard() {
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), children: [
      Container(
        key: const ValueKey('fetching'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.surface(context), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: AppTheme.neonCyan.withAlpha(20), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.cloud_download_rounded, color: AppTheme.neonCyan),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Resolving download...', style: TextStyle(color: AppTheme.onSurface(context), fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Extracting media details', style: TextStyle(color: AppTheme.dimText(context), fontSize: 13)),
            ])),
          ]),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(minHeight: 6, backgroundColor: AppTheme.background(context), valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.neonCyan)),
          ),
        ]),
      ),
    ]);
  }

  // ── Thumbnail helper ──
  Widget _buildThumbnail(DownloadEntity entity, Color accentColor, IconData fallbackIcon) {
    if (entity.thumbnailUrl != null && entity.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(entity.thumbnailUrl!, fit: BoxFit.cover, width: 64, height: 64,
          errorBuilder: (_, e, st) => Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: accentColor.withAlpha(20), borderRadius: BorderRadius.circular(12)),
            child: Icon(fallbackIcon, color: accentColor, size: 28),
          ),
        ),
      );
    }
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(color: accentColor.withAlpha(20), borderRadius: BorderRadius.circular(12)),
      child: Icon(fallbackIcon, color: accentColor, size: 28),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildProgressCard(BuildContext context, DownloadEntity entity) {
    final pct = (entity.progress * 100).round();
    final displayTitle = entity.title.isNotEmpty ? entity.title : 'Downloading…';

    return ListView(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), children: [
      Container(
        key: const ValueKey('progress'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface(context), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.neonCyan.withAlpha(30)),
          boxShadow: [BoxShadow(color: AppTheme.neonCyan.withAlpha(10), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildThumbnail(entity, AppTheme.neonCyan, Icons.download_rounded),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(displayTitle, style: TextStyle(color: AppTheme.onSurface(context), fontSize: 15, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                Text('${_formatBytes(entity.receivedBytes)} / ${_formatBytes(entity.totalBytes)}',
                  style: TextStyle(color: AppTheme.dimText(context), fontSize: 12)),
              ]),
            ])),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: entity.progress, minHeight: 8, backgroundColor: AppTheme.background(context), valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.neonCyan)),
            )),
            const SizedBox(width: 12),
            Text('$pct%', style: const TextStyle(color: AppTheme.neonCyan, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => context.read<DownloaderBloc>().add(const PauseDownloadEvent()),
              icon: const Icon(Icons.pause_rounded, size: 18),
              label: const Text('Pause'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.neonCyan, side: BorderSide(color: AppTheme.neonCyan.withAlpha(100)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => context.read<DownloaderBloc>().add(const ResetDownloaderEvent()),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.kErrorRed, side: BorderSide(color: AppTheme.kErrorRed.withAlpha(100)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
          ]),
        ]),
      ),
    ]);
  }

  Widget _buildPausedCard(BuildContext context, DownloadEntity entity) {
    final pct = (entity.progress * 100).round();
    final displayTitle = entity.title.isNotEmpty ? entity.title : 'Paused';

    return ListView(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface(context), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFA726).withAlpha(50)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildThumbnail(entity, const Color(0xFFFFA726), Icons.pause_circle_rounded),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(displayTitle, style: TextStyle(color: AppTheme.onSurface(context), fontSize: 15, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFFA726).withAlpha(20), borderRadius: BorderRadius.circular(4)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.pause_rounded, color: Color(0xFFFFA726), size: 12),
                  SizedBox(width: 4),
                  Text('Paused', style: TextStyle(color: Color(0xFFFFA726), fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 4),
              Text('$pct% • ${_formatBytes(entity.receivedBytes)} / ${_formatBytes(entity.totalBytes)}', style: TextStyle(color: AppTheme.dimText(context), fontSize: 12)),
            ])),
          ]),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: entity.progress, minHeight: 8, backgroundColor: AppTheme.background(context), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFA726))),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => context.read<DownloaderBloc>().add(const ResumeDownloadEvent()),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Resume'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726).withAlpha(30), foregroundColor: const Color(0xFFFFA726), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => context.read<DownloaderBloc>().add(const ResetDownloaderEvent()),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.kErrorRed, side: BorderSide(color: AppTheme.kErrorRed.withAlpha(100)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
          ]),
        ]),
      ),
    ]);
  }

  Widget _buildCompletedCard(BuildContext context, DownloadEntity entity) {
    final displayTitle = entity.title.isNotEmpty ? entity.title : 'Download complete';
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), children: [
      Container(
        key: const ValueKey('completed'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface(context), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2ECC71).withAlpha(50)),
          boxShadow: [BoxShadow(color: const Color(0xFF2ECC71).withAlpha(10), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildThumbnail(entity, const Color(0xFF2ECC71), Icons.check_circle_outline_rounded),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(displayTitle, style: TextStyle(color: AppTheme.onSurface(context), fontSize: 15, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF2ECC71).withAlpha(20), borderRadius: BorderRadius.circular(4)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded, color: Color(0xFF2ECC71), size: 12),
                    SizedBox(width: 4),
                    Text('Complete', style: TextStyle(color: Color(0xFF2ECC71), fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(width: 8),
                Text(_formatBytes(entity.totalBytes), style: TextStyle(color: AppTheme.dimText(context), fontSize: 12)),
              ]),
            ])),
          ]),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => context.read<DownloaderBloc>().add(const ResetDownloaderEvent()),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Dismiss'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.onSurface(context).withAlpha(179), side: BorderSide(color: AppTheme.divider(context)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
          )),
        ]),
      ),
    ]);
  }

  Widget _buildFailedCard(BuildContext context, String message) {
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), children: [
      Container(
        key: const ValueKey('failed'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface(context), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.kErrorRed.withAlpha(50)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: AppTheme.kErrorRed.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.error_outline_rounded, color: AppTheme.kErrorRed, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Download Failed', style: TextStyle(color: AppTheme.onSurface(context), fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(message, style: TextStyle(color: AppTheme.dimText(context), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
          ]),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => context.read<DownloaderBloc>().add(const ResetDownloaderEvent()),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Dismiss'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.onSurface(context).withAlpha(179), side: BorderSide(color: AppTheme.divider(context)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
          )),
        ]),
      ),
    ]);
  }
}
