import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/biometric_helper.dart';
import '../../../../core/utils/file_manager.dart';
import '../widgets/media_player_sheet.dart';

enum LibraryFilter { all, video, audio }
enum ViewMode { list, grid }

/// Displays downloaded files with Share, Open, Lock, and Delete actions.
class FilesPage extends StatefulWidget {
  final VoidCallback? onRefreshRequested;

  const FilesPage({super.key, this.onRefreshRequested});

  /// Allows external callers to trigger a refresh.
  static final refreshNotifier = ValueNotifier<int>(0);

  @override
  State<FilesPage> createState() => FilesPageState();
}

class FilesPageState extends State<FilesPage>
    with AutomaticKeepAliveClientMixin {
  List<DownloadedFileInfo> _files = [];
  bool _loading = true;

  LibraryFilter _currentFilter = LibraryFilter.all;
  ViewMode _viewMode = ViewMode.list;

  /// Tracks which file paths are locked (private vault).
  final Set<String> _lockedFiles = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
    FilesPage.refreshNotifier.addListener(_onExternalRefresh);
  }

  @override
  void dispose() {
    FilesPage.refreshNotifier.removeListener(_onExternalRefresh);
    super.dispose();
  }

  void _onExternalRefresh() => _loadFiles();

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
  Future<bool> _ensureUnlocked(DownloadedFileInfo file) async {
    if (!_lockedFiles.contains(file.path)) return true;
    final ok = await BiometricHelper.authenticate(
      reason: 'Authenticate to access "${file.displayTitle}"',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: AppTheme.kSurface,
        behavior: SnackBarBehavior.floating,
        content: Text('Authentication failed',
            style: TextStyle(color: AppTheme.kErrorRed, fontSize: 13)),
      ));
    }
    return ok;
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _openFile(DownloadedFileInfo file) async {
    if (!await _ensureUnlocked(file)) return;

    if (file.isVideo || file.isAudio) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MediaPlayerSheet(file: file),
      );
    } else {
      await OpenFilex.open(file.path);
    }
  }

  Future<void> _shareFile(DownloadedFileInfo file) async {
    if (!await _ensureUnlocked(file)) return;
    await Share.shareXFiles([XFile(file.path)]);
  }

  void _toggleLock(DownloadedFileInfo file) {
    setState(() {
      if (_lockedFiles.contains(file.path)) {
        _lockedFiles.remove(file.path);
      } else {
        _lockedFiles.add(file.path);
      }
    });

    final isNowLocked = _lockedFiles.contains(file.path);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
                color: isNowLocked ? const Color(0xFFFFA726) : AppTheme.neonCyan,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ));
  }

  Future<void> _deleteFile(DownloadedFileInfo file) async {
    final confirmed = await _showDeleteDialog(file.displayTitle);
    if (confirmed == true) {
      final ok = await FileManager.deleteFile(file.path);
      if (ok && mounted) {
        _lockedFiles.remove(file.path);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.kSurface,
          content: Text('${file.displayTitle} deleted',
              style: const TextStyle(color: AppTheme.neonCyan, fontSize: 13)),
          behavior: SnackBarBehavior.floating,
        ));
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
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.kErrorRed.withAlpha(25)),
            child: const Icon(Icons.delete_rounded,
                color: AppTheme.kErrorRed, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Delete File',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                color: AppTheme.kTextDim, fontSize: 14, height: 1.4),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                  text: name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.kTextDim)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.kErrorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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

    return Scaffold(
      backgroundColor: AppTheme.kDeepBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildToolbar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.neonCyan))
                  : displayedFiles.isEmpty
                      ? _buildEmpty()
                      : _buildFileList(displayedFiles),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
      color: AppTheme.kDeepBg,
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppTheme.neonPurple, AppTheme.neonCyan],
            ).createShader(rect),
            child: const Icon(Icons.video_library_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Library',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                if (!_loading)
                  Text(
                    '${_files.length} file${_files.length == 1 ? '' : 's'}'
                    '${_lockedFiles.isNotEmpty ? ' • ${_lockedFiles.length} locked' : ''}',
                    style: const TextStyle(
                        color: AppTheme.kTextDim, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white70, size: 22),
            onPressed: _loadFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Filters
          _buildFilterChip('All', LibraryFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip('Video', LibraryFilter.video),
          const SizedBox(width: 8),
          _buildFilterChip('Audio', LibraryFilter.audio),
          const Spacer(),
          // View Mode Toggles
          Container(
            decoration: BoxDecoration(
              color: AppTheme.kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                _buildViewModeButton(Icons.view_list_rounded, ViewMode.list),
                _buildViewModeButton(Icons.grid_view_rounded, ViewMode.grid),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, LibraryFilter filter) {
    final isSelected = _currentFilter == filter;
    return InkWell(
      onTap: () => setState(() => _currentFilter = filter),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.neonCyan.withAlpha(25) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.neonCyan : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.neonCyan : AppTheme.kTextDim,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeButton(IconData icon, ViewMode mode) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : AppTheme.kTextDim,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.neonCyan.withAlpha(12)),
            child: Icon(Icons.video_library_rounded,
                size: 40, color: AppTheme.neonCyan.withAlpha(70)),
          ),
          const SizedBox(height: 20),
          Text('Your Library is empty',
              style: TextStyle(
                  color: Colors.white.withAlpha(140),
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Downloaded media will appear here.',
              style: TextStyle(
                  color: Colors.white.withAlpha(70), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFileList(List<DownloadedFileInfo> displayedFiles) {
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
                final isLocked = _lockedFiles.contains(file.path);
                return _FileListCard(
                  file: file,
                  isLocked: isLocked,
                  onOpen: () => _openFile(file),
                  onShare: () => _shareFile(file),
                  onLock: () => _toggleLock(file),
                  onDelete: () => _deleteFile(file),
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
                final isLocked = _lockedFiles.contains(file.path);
                return _FileGridCard(
                  file: file,
                  isLocked: isLocked,
                  onOpen: () => _openFile(file),
                  onShare: () => _shareFile(file),
                  onLock: () => _toggleLock(file),
                  onDelete: () => _deleteFile(file),
                );
              },
            ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  File List Card Widget
// ──────────────────────────────────────────────────────────────

class _FileListCard extends StatelessWidget {
  final DownloadedFileInfo file;
  final bool isLocked;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onLock;
  final VoidCallback onDelete;

  const _FileListCard({
    required this.file,
    required this.isLocked,
    required this.onOpen,
    required this.onShare,
    required this.onLock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isLocked
        ? const Color(0xFFFFA726)
        : file.isVideo
            ? AppTheme.neonPurple
            : file.isAudio
                ? AppTheme.neonCyan
                : const Color(0xFFFFA726);

    final iconData = isLocked
        ? Icons.lock_rounded
        : file.isVideo
            ? Icons.videocam_rounded
            : file.isAudio
                ? Icons.audiotrack_rounded
                : Icons.insert_drive_file_rounded;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.kGlassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withAlpha(isLocked ? 50 : 25)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                // Icon / Thumbnail placeholder
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withAlpha(50),
                        accentColor.withAlpha(18)
                      ],
                    ),
                    boxShadow: isLocked
                        ? [
                            BoxShadow(
                                color: const Color(0xFFFFA726).withAlpha(30),
                                blurRadius: 10)
                          ]
                        : [],
                  ),
                  child: file.metadata?.thumbnailUrl != null && !isLocked
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            file.metadata!.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(iconData, color: accentColor, size: 26),
                          ),
                        )
                      : Icon(iconData, color: accentColor, size: 26),
                ),
                const SizedBox(width: 14),
                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(file.displayTitle,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (file.displayAuthor != 'Unknown Author')
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 2),
                          child: Text(file.displayAuthor,
                              style: const TextStyle(
                                  color: AppTheme.kTextDim, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _MetaChip(
                              text: file.formattedSize, color: accentColor),
                          const SizedBox(width: 8),
                          _MetaChip(
                              text: file.extension.toUpperCase(),
                              color: accentColor,
                              outlined: true),
                          if (file.displayDuration != null) ...[
                            const SizedBox(width: 8),
                            _MetaChip(
                                text: file.displayDuration!,
                                color: Colors.white54),
                          ],
                          if (isLocked) ...[
                            const SizedBox(width: 8),
                            const _MetaChip(
                                text: '🔒 VAULT',
                                color: Color(0xFFFFA726),
                                outlined: true),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Action menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: Colors.white54, size: 20),
                  color: AppTheme.kSurface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'play') onOpen();
                    if (value == 'share') onShare();
                    if (value == 'lock') onLock();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'play',
                      child: Row(
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                              color: AppTheme.neonCyan, size: 18),
                          const SizedBox(width: 10),
                          Text(file.isVideo ? 'Play Video' : 'Play Audio',
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: const Row(
                        children: [
                          Icon(Icons.share_rounded,
                              color: AppTheme.neonPurple, size: 18),
                          SizedBox(width: 10),
                          Text('Share', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'lock',
                      child: Row(
                        children: [
                          Icon(
                            isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                            color: const Color(0xFFFFA726),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(isLocked ? 'Unlock File' : 'Move to Vault',
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              color: AppTheme.kErrorRed.withAlpha(200), size: 18),
                          const SizedBox(width: 10),
                          const Text('Delete',
                              style: TextStyle(color: AppTheme.kErrorRed)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  File Grid Card Widget
// ──────────────────────────────────────────────────────────────

class _FileGridCard extends StatelessWidget {
  final DownloadedFileInfo file;
  final bool isLocked;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onLock;
  final VoidCallback onDelete;

  const _FileGridCard({
    required this.file,
    required this.isLocked,
    required this.onOpen,
    required this.onShare,
    required this.onLock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isLocked
        ? const Color(0xFFFFA726)
        : file.isVideo
            ? AppTheme.neonPurple
            : file.isAudio
                ? AppTheme.neonCyan
                : const Color(0xFFFFA726);

    final iconData = isLocked
        ? Icons.lock_rounded
        : file.isVideo
            ? Icons.videocam_rounded
            : file.isAudio
                ? Icons.audiotrack_rounded
                : Icons.insert_drive_file_rounded;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.kGlassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withAlpha(isLocked ? 50 : 25)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thumbnail area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withAlpha(30),
                        accentColor.withAlpha(10)
                      ],
                    ),
                  ),
                  child: file.metadata?.thumbnailUrl != null && !isLocked
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(
                            file.metadata!.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(iconData, color: accentColor, size: 40),
                          ),
                        )
                      : Icon(iconData, color: accentColor, size: 40),
                ),
              ),
              // Info area
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(file.displayTitle,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MetaChip(text: file.formattedSize, color: accentColor),
                        const Spacer(),
                        if (isLocked)
                          const Icon(Icons.lock_rounded, color: Color(0xFFFFA726), size: 14)
                        else
                          Icon(iconData, color: AppTheme.kTextDim, size: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Common Utilities
// ──────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool outlined;

  const _MetaChip({
    required this.text,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withAlpha(18),
        borderRadius: BorderRadius.circular(4),
        border:
            outlined ? Border.all(color: color.withAlpha(60), width: 0.8) : null,
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
