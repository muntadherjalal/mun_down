import 'package:flutter/material.dart';
import '../../../../core/themes/app_theme.dart';

class FetchingPill extends StatelessWidget {
  const FetchingPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.kSurface.withAlpha(240),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.neonCyan.withAlpha(50)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppTheme.neonCyan),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Fetching qualities...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
