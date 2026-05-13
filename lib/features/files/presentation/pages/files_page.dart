import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/biometric_helper.dart';
import '../../../../core/utils/file_manager.dart';
import '../widgets/video_player_view.dart';

/// ─────────────────────────────────────────────────────────────
///  Design Tokens
/// ─────────────────────────────────────────────────────────────
const _kNeonCyan = Color(0xFF00CEC9);
const _kNeonPurple = Color(0xFF6C5CE7);
const _kNeonGreen = Color(0xFF2ECC71);
const _kNeonAmber = Color(0xFFFFA726);
const _kSurface = Color(0xFF1E1E2C);
const _kDeepBg = Color(0xFF141422);
const _kErrorRed = Color(0xFFFF6B6B);
const _kTextDim = Color(0x99E0E0E0);
const _kGlassWhite = Color(0x14FFFFFF);

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
    if (mounted) setState(() { _files = files; _loading = false; });
  }

  // ── Biometric gate ──────────────────────────────────────────

  /// Returns `true` if the file is unlocked (or not locked).
  /// If locked, triggers biometric auth and returns the result.
  Future<bool> _ensureUnlocked(DownloadedFileInfo file) async {
    if (!_lockedFiles.contains(file.path)) return true;
    final ok = await BiometricHelper.authenticate(
      reason: 'Authenticate to access "${file.name}"',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _kSurface,
        behavior: SnackBarBehavior.floating,
        content: const Text('Authentication failed',
            style: TextStyle(color: _kErrorRed, fontSize: 13)),
      ));
    }
    return ok;
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _openFile(DownloadedFileInfo file) async {
    if (!await _ensureUnlocked(file)) return;

    if (file.isVideo) {
      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              VideoPlayerView(filePath: file.path, title: file.name),
          transitionsBuilder: (context, anim, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: FadeTransition(opacity: anim, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } else {
      await OpenFilex.open(file.path);
    }
  }

  Future<void> _shareFile(DownloadedFileInfo file) async {
    if (!await _ensureUnlocked(file)) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
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
      backgroundColor: _kSurface,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      content: Row(
        children: [
          Icon(
            isNowLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: isNowLocked ? _kNeonAmber : _kNeonGreen,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isNowLocked
                  ? '${file.name} locked — biometric required'
                  : '${file.name} unlocked',
              style: TextStyle(
                color: isNowLocked ? _kNeonAmber : _kNeonGreen,
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
    final confirmed = await _showDeleteDialog(file.name);
    if (confirmed == true) {
      final ok = await FileManager.deleteFile(file.path);
      if (ok && mounted) {
        _lockedFiles.remove(file.path);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _kSurface,
          content: Text('${file.name} deleted',
              style: const TextStyle(color: _kNeonCyan, fontSize: 13)),
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
        backgroundColor: _kDeepBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _kErrorRed.withAlpha(25)),
            child: const Icon(Icons.delete_rounded, color: _kErrorRed, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Delete File',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: _kTextDim, fontSize: 14, height: 1.4),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(text: name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _kTextDim)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kErrorRed, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kNeonCyan))
                : _files.isEmpty
                    ? _buildEmpty()
                    : _buildFileList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      color: _kDeepBg,
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (rect) =>
                const LinearGradient(colors: [_kNeonPurple, _kNeonCyan]).createShader(rect),
            child: const Icon(Icons.folder_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Downloaded Files',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                if (!_loading)
                  Text(
                    '${_files.length} file${_files.length == 1 ? '' : 's'}'
                    '${_lockedFiles.isNotEmpty ? ' • ${_lockedFiles.length} locked' : ''}',
                    style: const TextStyle(color: _kTextDim, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
            onPressed: _loadFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _kNeonCyan.withAlpha(12)),
            child: Icon(Icons.download_done_rounded, size: 40, color: _kNeonCyan.withAlpha(70)),
          ),
          const SizedBox(height: 20),
          Text('No files yet',
              style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Your downloads will appear here.',
              style: TextStyle(color: Colors.white.withAlpha(70), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return RefreshIndicator(
      color: _kNeonCyan,
      backgroundColor: _kSurface,
      onRefresh: _loadFiles,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _files.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final file = _files[index];
          final isLocked = _lockedFiles.contains(file.path);
          return _FileCard(
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
//  File Card Widget
// ──────────────────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  final DownloadedFileInfo file;
  final bool isLocked;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onLock;
  final VoidCallback onDelete;

  const _FileCard({
    required this.file,
    required this.isLocked,
    required this.onOpen,
    required this.onShare,
    required this.onLock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Locked files use amber as accent.
    final Color accentColor;
    final IconData iconData;

    if (isLocked) {
      accentColor = _kNeonAmber;
      iconData = Icons.lock_rounded;
    } else if (file.isVideo) {
      accentColor = _kNeonPurple;
      iconData = Icons.videocam_rounded;
    } else if (file.isAudio) {
      accentColor = _kNeonCyan;
      iconData = Icons.audiotrack_rounded;
    } else {
      accentColor = const Color(0xFFFFA726);
      iconData = Icons.insert_drive_file_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: _kGlassWhite,
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
                // Icon
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accentColor.withAlpha(50), accentColor.withAlpha(18)],
                    ),
                    boxShadow: isLocked
                        ? [BoxShadow(color: _kNeonAmber.withAlpha(30), blurRadius: 10)]
                        : [],
                  ),
                  child: Icon(iconData, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(file.name,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        _MetaChip(text: file.formattedSize, color: accentColor),
                        const SizedBox(width: 8),
                        _MetaChip(text: file.formattedDate, color: Colors.white54),
                        const SizedBox(width: 8),
                        _MetaChip(text: file.extension.toUpperCase(), color: accentColor, outlined: true),
                        if (isLocked) ...[
                          const SizedBox(width: 8),
                          _MetaChip(text: '🔒 VAULT', color: _kNeonAmber, outlined: true),
                        ],
                      ]),
                    ],
                  ),
                ),
                // Action buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionIcon(icon: Icons.play_arrow_rounded, color: _kNeonGreen, tooltip: 'Play', onTap: onOpen),
                    _ActionIcon(
                      icon: isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: isLocked ? _kNeonAmber : Colors.white38,
                      tooltip: isLocked ? 'Unlock' : 'Lock',
                      onTap: onLock,
                    ),
                    _ActionIcon(icon: Icons.share_rounded, color: _kNeonCyan, tooltip: 'Share', onTap: onShare),
                    _ActionIcon(icon: Icons.delete_outline_rounded, color: _kErrorRed, tooltip: 'Delete', onTap: onDelete),
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

class _MetaChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool outlined;
  const _MetaChip({required this.text, required this.color, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withAlpha(18),
        borderRadius: BorderRadius.circular(4),
        border: outlined ? Border.all(color: color.withAlpha(60), width: 0.8) : null,
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionIcon({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color.withAlpha(180), size: 20),
        ),
      ),
    );
  }
}
