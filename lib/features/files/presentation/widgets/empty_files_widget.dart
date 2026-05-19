import 'package:flutter/material.dart';
import '../../../../core/themes/app_theme.dart';

class EmptyFilesWidget extends StatelessWidget {
  const EmptyFilesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.neonCyan.withAlpha(12),
            ),
            child: Icon(
              Icons.video_library_rounded,
              size: 40,
              color: AppTheme.neonCyan.withAlpha(70),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your Library is empty',
            style: TextStyle(
              color: AppTheme.onSurface(context).withAlpha(140),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Downloaded media will appear here.',
            style: TextStyle(
              color: AppTheme.onSurface(context).withAlpha(70),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
