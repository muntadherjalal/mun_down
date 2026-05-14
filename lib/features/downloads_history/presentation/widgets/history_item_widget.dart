import 'package:flutter/material.dart';
import '../../domain/entities/download_history_item.dart';

class HistoryItemWidget extends StatelessWidget {
  final DownloadHistoryItem item;

  const HistoryItemWidget({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final meta = item.metadata;
    final isAudio = meta.format.toLowerCase() == 'audio';
    
    // Format date nicely
    final date = item.downloadDate;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    
    // Format file size
    final sizeMb = (meta.fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12.0),
        leading: _buildThumbnail(context, isAudio),
        title: Text(
          meta.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isAudio ? Icons.audiotrack : Icons.video_library,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${meta.quality} • $sizeMb MB',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, bool isAudio) {
    if (item.metadata.thumbnailUrl != null && item.metadata.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.network(
          item.metadata.thumbnailUrl!,
          width: 80,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(context, isAudio),
        ),
      );
    }
    return _buildFallbackIcon(context, isAudio);
  }

  Widget _buildFallbackIcon(BuildContext context, bool isAudio) {
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Icon(
        isAudio ? Icons.audiotrack : Icons.videocam,
        size: 32,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
