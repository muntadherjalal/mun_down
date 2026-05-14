import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/biometric_helper.dart';
import '../../../../core/utils/file_manager.dart';
import '../../../../injection_container.dart';
// غيرنا الاستيراد حتى يقرأ صفحة المشغل الأساسية
import '../widgets/video_player_view.dart';
import '../widgets/widgets.dart';
import '../bloc/bloc.dart';
import '../../../downloader/presentation/bloc/downloader_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum LibraryFilter { all, video, audio }

enum ViewMode { list, grid }

/// Displays downloaded files with Share, Open, Lock, and Delete actions.
class FilesPage extends StatefulWidget {
  final VoidCallback? onRefreshRequested;

  const FilesPage({super.key, this.onRefreshRequested});

  @override
  State<FilesPage> createState() => FilesPageState();
}

class FilesPageState extends State<FilesPage>
    with AutomaticKeepAliveClientMixin {
  List<DownloadedFileInfo> _files = [];
  bool _loading = true;

  LibraryFilter _currentFilter = LibraryFilter.all;
  ViewMode _viewMode = ViewMode.list;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> refreshFiles() => _loadFiles();

  Future<void> _loadFiles() async {
    if (mounted) setState(() => _loading = true);
    final files = await FileManager.scanFiles();
    if (mounted) {
      setState(() {
        _files = files;
        _loading = false;
      });
    }
  }

  // ── Biometric gate ──────────────────────────────────────────

  /// Returns `true` if the file is unlocked (or not locked).
  /// If locked, triggers biometric auth and returns the result.
  Future<bool> _ensureUnlocked(DownloadedFileInfo file, Set<String> lockedFiles) async {
    if (!lockedFiles.contains(file.path)) return true;
    final ok = await BiometricHelper.authenticate(
      reason: 'Authenticate to access "${file.displayTitle}"',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.kSurface,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Authentication failed',
            style: TextStyle(color: AppTheme.kErrorRed, fontSize: 13),
          ),
        ),
      );
    }
    return ok;
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _openFile(DownloadedFileInfo file, Set<String> lockedFiles) async {
    if (!await _ensureUnlocked(file, lockedFiles)) return;

    if (file.isVideo || file.isAudio) {
      if (!mounted) return;
      // 🚀 هنا التعديل السحري: نفتح الفيديو بشاشة كاملة (صفحة جديدة)
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => VideoPlayerView(file: file)));
    } else {
      await OpenFilex.open(file.path);
    }
  }

  Future<void> _shareFile(DownloadedFileInfo file, Set<String> lockedFiles) async {
    if (!await _ensureUnlocked(file, lockedFiles)) return;
    await Share.shareXFiles([XFile(file.path)]);
  }

  void _toggleLock(BuildContext context, DownloadedFileInfo file, Set<String> lockedFiles) {
    context.read<FilesBloc>().add(ToggleFileLockEvent(file.path));

    final isNowLocked = !lockedFiles.contains(file.path);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.kSurface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Icon(
              isNowLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: isNowLocked ? const Color(0xFFFFA726) : AppTheme.neonCyan,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isNowLocked
                    ? '${file.displayTitle} locked — biometric required'
                    : '${file.displayTitle} unlocked',
                style: TextStyle(
                  color: isNowLocked
                      ? const Color(0xFFFFA726)
                      : AppTheme.neonCyan,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFile(DownloadedFileInfo file, Set<String> lockedFiles) async {
    final confirmed = await _showDeleteDialog(file.displayTitle);
    if (confirmed == true) {
      final ok = await FileManager.deleteFile(file.path);
      if (ok && mounted) {
        if (lockedFiles.contains(file.path)) {
          context.read<FilesBloc>().add(ToggleFileLockEvent(file.path));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.kSurface,
            content: Text(
              '${file.displayTitle} deleted',
              style: const TextStyle(color: AppTheme.neonCyan, fontSize: 13),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadFiles();
      }
    }
  }

  Future<bool?> _showDeleteDialog(String name) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.kDeepBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.kErrorRed.withAlpha(25),
              ),
              child: const Icon(
                Icons.delete_rounded,
                color: AppTheme.kErrorRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete File',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: AppTheme.kTextDim,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.kTextDim),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.kErrorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Apply filtering
    List<DownloadedFileInfo> displayedFiles = _files;
    if (_currentFilter == LibraryFilter.video) {
      displayedFiles = _files.where((f) => f.isVideo).toList();
    } else if (_currentFilter == LibraryFilter.audio) {
      displayedFiles = _files.where((f) => f.isAudio).toList();
    }

    return BlocProvider(
      create: (_) => sl<FilesBloc>()..add(LoadLockedFilesEvent()),
      child: BlocBuilder<FilesBloc, FilesState>(
        builder: (context, state) {
          final lockedFiles = state is FilesLoaded ? state.lockedFiles : <String>{};
          return BlocListener<DownloaderBloc, DownloaderState>(
            listener: (context, downloaderState) {
              if (downloaderState is DownloaderCompletedState) {
                _loadFiles();
              }
            },
            child: Scaffold(
              backgroundColor: AppTheme.kDeepBg,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(lockedFiles),
                  FilesControlBar(
                    currentFilter: _currentFilter,
                    onFilterChanged: (filter) =>
                        setState(() => _currentFilter = filter),
                    viewMode: _viewMode,
                    onViewModeChanged: (mode) =>
                        setState(() => _viewMode = mode),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.neonCyan,
                            ),
                          )
                        : displayedFiles.isEmpty
                        ? const EmptyFilesWidget()
                        : _buildFileList(displayedFiles, lockedFiles, context),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Set<String> lockedFiles) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
      color: AppTheme.kDeepBg,
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppTheme.neonPurple, AppTheme.neonCyan],
            ).createShader(rect),
            child: const Icon(
              Icons.video_library_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!_loading)
                  Text(
                    '${_files.length} file${_files.length == 1 ? '' : 's'}'
                    '${lockedFiles.isNotEmpty ? ' • ${lockedFiles.length} locked' : ''}',
                    style: const TextStyle(
                      color: AppTheme.kTextDim,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white70,
              size: 22,
            ),
            onPressed: _loadFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(List<DownloadedFileInfo> displayedFiles, Set<String> lockedFiles, BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.neonCyan,
      backgroundColor: AppTheme.kSurface,
      onRefresh: _loadFiles,
      child: _viewMode == ViewMode.list
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: displayedFiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final file = displayedFiles[index];
                final isLocked = lockedFiles.contains(file.path);
                return FileListCard(
                  file: file,
                  isLocked: isLocked,
                  onOpen: () => _openFile(file, lockedFiles),
                  onShare: () => _shareFile(file, lockedFiles),
                  onLock: () => _toggleLock(context, file, lockedFiles),
                  onDelete: () => _deleteFile(file, lockedFiles),
                );
              },
            )
          : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: displayedFiles.length,
              itemBuilder: (context, index) {
                final file = displayedFiles[index];
                final isLocked = lockedFiles.contains(file.path);
                return FileGridCard(
                  file: file,
                  isLocked: isLocked,
                  onOpen: () => _openFile(file, lockedFiles),
                  onShare: () => _shareFile(file, lockedFiles),
                  onLock: () => _toggleLock(context, file, lockedFiles),
                  onDelete: () => _deleteFile(file, lockedFiles),
                );
              },
            ),
    );
  }
}
