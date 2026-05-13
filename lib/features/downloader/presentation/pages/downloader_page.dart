import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_theme.dart';
import '../../domain/entities/download_entity.dart';
import '../bloc/downloader_bloc.dart';

/// ─────────────────────────────────────────────────────────────
///  Downloader Page (Active/Completed/Failed Downloads Only)
/// ─────────────────────────────────────────────────────────────
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
      backgroundColor: AppTheme.kDeepBg,
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

  // ────────────────────────────────────────────────────────────
  //  App Bar
  // ────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppTheme.neonPurple, AppTheme.neonCyan],
            ).createShader(rect),
            child: const Icon(Icons.downloading_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          const Text(
            'Downloads',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 24,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  State Handling
  // ────────────────────────────────────────────────────────────

  Widget _buildStateContent(BuildContext context, DownloaderState state) {
    if (state is DownloaderInitialState) {
      return _buildEmptyState();
    } else if (state is DownloaderFetchingState) {
      return _buildFetchingCard();
    } else if (state is DownloaderProgressState) {
      return _buildProgressCard(context, state.entity);
    } else if (state is DownloaderCompletedState) {
      return _buildCompletedCard(context, state.entity);
    } else if (state is DownloaderFailedState) {
      return _buildFailedCard(context, state.message);
    }
    return const SizedBox.shrink();
  }

  // ────────────────────────────────────────────────────────────
  //  Empty State
  // ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download_rounded, color: AppTheme.kTextDim.withAlpha(80), size: 64),
          const SizedBox(height: 16),
          const Text(
            'No downloads yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse the web and tap Download to start',
            style: TextStyle(
              color: AppTheme.kTextDim.withAlpha(180),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Fetching State
  // ────────────────────────────────────────────────────────────

  Widget _buildFetchingCard() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Container(
          key: const ValueKey('fetching'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.kSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.neonCyan.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_download_rounded, color: AppTheme.neonCyan),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resolving download...',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('Extracting media details',
                            style: TextStyle(color: AppTheme.kTextDim, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: AppTheme.kDeepBg,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  In-Progress Card
  // ────────────────────────────────────────────────────────────

  Widget _buildProgressCard(BuildContext context, DownloadEntity entity) {
    final titleParts = entity.title.split('.');
    final formatStr = titleParts.length > 1 ? titleParts.last.toUpperCase() : 'FILE';
    final displayTitle = entity.title.isNotEmpty ? entity.title : 'Unknown file';
    final pct = (entity.progress * 100).round();
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Container(
          key: const ValueKey('progress'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.neonCyan.withAlpha(30)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonCyan.withAlpha(10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail or Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.neonCyan.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.insert_drive_file_rounded, color: AppTheme.neonCyan, size: 28),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        _buildFormatBadge(formatStr),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Progress Bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: entity.progress,
                        minHeight: 6,
                        backgroundColor: AppTheme.kDeepBg,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$pct%', style: const TextStyle(color: AppTheme.neonCyan, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              // Stats
              Row(
                children: [
                  Text(
                    '${(entity.progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppTheme.kTextDim, fontSize: 12),
                  ),
                  const Text('  •  ', style: TextStyle(color: AppTheme.kTextDim, fontSize: 12)),
                  const Text(
                    'Downloading...',
                    style: TextStyle(color: AppTheme.kTextDim, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Pause is not fully implemented in DownloadDataSource yet,
                        // but we wire the UI for it.
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pause not implemented yet')));
                      },
                      icon: const Icon(Icons.pause_rounded, size: 18),
                      label: const Text('Pause'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.neonCyan,
                        side: BorderSide(color: AppTheme.neonCyan.withAlpha(100)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<DownloaderBloc>().add(const ResetDownloaderEvent());
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.kErrorRed,
                        side: BorderSide(color: AppTheme.kErrorRed.withAlpha(100)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Completed Card
  // ────────────────────────────────────────────────────────────

  Widget _buildCompletedCard(BuildContext context, DownloadEntity entity) {
    final titleParts = entity.title.split('.');
    final formatStr = titleParts.length > 1 ? titleParts.last.toUpperCase() : 'FILE';
    final displayTitle = entity.title.isNotEmpty ? entity.title : 'Unknown file';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Container(
          key: const ValueKey('completed'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2ECC71).withAlpha(50)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2ECC71).withAlpha(10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2ECC71), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2ECC71).withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_rounded, color: Color(0xFF2ECC71), size: 12),
                                  SizedBox(width: 4),
                                  Text('Complete', style: TextStyle(color: Color(0xFF2ECC71), fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Done', style: TextStyle(color: AppTheme.kTextDim, fontSize: 12)),
                            const Text('  •  ', style: TextStyle(color: AppTheme.kTextDim, fontSize: 12)),
                            Text(formatStr.toUpperCase(), style: const TextStyle(color: AppTheme.kTextDim, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // User can go to Library tab to open it
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Go to Library tab to manage your files')));
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('Library'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71).withAlpha(30),
                        foregroundColor: const Color(0xFF2ECC71),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<DownloaderBloc>().add(const ResetDownloaderEvent());
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Dismiss'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withAlpha(40)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Failed Card
  // ────────────────────────────────────────────────────────────

  Widget _buildFailedCard(BuildContext context, String message) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Container(
          key: const ValueKey('failed'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.kErrorRed.withAlpha(50)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.kErrorRed.withAlpha(10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.kErrorRed.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.error_outline_rounded, color: AppTheme.kErrorRed, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Download Failed',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.kErrorRed.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close_rounded, color: AppTheme.kErrorRed, size: 12),
                              SizedBox(width: 4),
                              Text('Failed', style: TextStyle(color: AppTheme.kErrorRed, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          style: const TextStyle(color: AppTheme.kTextDim, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.read<DownloaderBloc>().add(const ResetDownloaderEvent());
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.kErrorRed.withAlpha(30),
                        foregroundColor: AppTheme.kErrorRed,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<DownloaderBloc>().add(const ResetDownloaderEvent());
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Dismiss'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withAlpha(40)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Helpers
  // ────────────────────────────────────────────────────────────

  Widget _buildFormatBadge(String formatStr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.neonPurple.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.neonPurple.withAlpha(60), width: 0.8),
      ),
      child: Text(
        formatStr.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.neonPurple,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
