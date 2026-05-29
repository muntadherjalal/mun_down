import 'package:flutter/material.dart';
import '../../../../core/themes/app_theme.dart';
import '../../domain/entities/downloaded_file_info.dart';
import 'meta_chip.dart';

class FileGridCard extends StatelessWidget {
  final DownloadedFileInfo file;
  final bool isLocked;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onLock;
  final VoidCallback onDelete;

  const FileGridCard({
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
        color: AppTheme.glass(context),
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
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withAlpha(30),
                        accentColor.withAlpha(10),
                      ],
                    ),
                  ),
                  child: file.metadata?.thumbnailUrl != null && !isLocked
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
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
                    Text(
                      file.displayTitle,
                      style: TextStyle(
                        color: AppTheme.onSurface(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        MetaChip(text: file.formattedSize, color: accentColor),
                        const Spacer(),
                        if (isLocked)
                          const Icon(
                            Icons.lock_rounded,
                            color: Color(0xFFFFA726),
                            size: 14,
                          )
                        else
                          Icon(iconData, color: AppTheme.dimText(context), size: 14),
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
