import 'package:flutter/material.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/file_manager.dart';
import 'meta_chip.dart';

class FileListCard extends StatelessWidget {
  final DownloadedFileInfo file;
  final bool isLocked;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onLock;
  final VoidCallback onDelete;

  const FileListCard({
    super.key,
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
                        accentColor.withAlpha(18),
                      ],
                    ),
                    boxShadow: isLocked
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFA726).withAlpha(30),
                              blurRadius: 10,
                            ),
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
                      Text(
                        file.displayTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (file.displayAuthor != 'Unknown Author')
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 2),
                          child: Text(
                            file.displayAuthor,
                            style: const TextStyle(
                              color: AppTheme.kTextDim,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          MetaChip(
                            text: file.formattedSize,
                            color: accentColor,
                          ),
                          const SizedBox(width: 8),
                          MetaChip(
                            text: file.extension.toUpperCase(),
                            color: accentColor,
                            outlined: true,
                          ),
                          if (file.displayDuration != null) ...[
                            const SizedBox(width: 8),
                            MetaChip(
                              text: file.displayDuration!,
                              color: Colors.white54,
                            ),
                          ],
                          if (isLocked) ...[
                            const SizedBox(width: 8),
                            const MetaChip(
                              text: '🔒 VAULT',
                              color: Color(0xFFFFA726),
                              outlined: true,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Action menu
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                  color: AppTheme.kSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: AppTheme.neonCyan,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            file.isVideo ? 'Play Video' : 'Play Audio',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: const Row(
                        children: [
                          Icon(
                            Icons.share_rounded,
                            color: AppTheme.neonPurple,
                            size: 18,
                          ),
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
                            isLocked
                                ? Icons.lock_open_rounded
                                : Icons.lock_rounded,
                            color: const Color(0xFFFFA726),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isLocked ? 'Unlock File' : 'Move to Vault',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: AppTheme.kErrorRed.withAlpha(200),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Delete',
                            style: TextStyle(color: AppTheme.kErrorRed),
                          ),
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
