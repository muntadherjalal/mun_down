import 'package:flutter/material.dart';
import '../../../../core/themes/app_theme.dart';

class BrowserBottomBar extends StatelessWidget {
  final bool isStartPage;
  final bool isLoading;
  final bool isFetchingStreams;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onReload;
  final VoidCallback onHistory;
  final VoidCallback onBookmarks;
  final VoidCallback onDownloadPressed;

  const BrowserBottomBar({
    super.key,
    required this.isStartPage,
    required this.isLoading,
    required this.isFetchingStreams,
    required this.onBack,
    required this.onForward,
    required this.onHome,
    required this.onReload,
    required this.onHistory,
    required this.onBookmarks,
    required this.onDownloadPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        boxShadow: [
          BoxShadow(
            color: AppTheme.isDark(context)
                ? Colors.black.withAlpha(60)
                : Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BottomNavIcon(
                icon: Icons.arrow_back_ios_rounded,
                label: 'Back',
                onTap: onBack,
              ),
              _BottomNavIcon(
                icon: Icons.arrow_forward_ios_rounded,
                label: 'Forward',
                onTap: onForward,
              ),
              _BottomNavIcon(
                icon: Icons.home_rounded,
                label: 'Home',
                onTap: onHome,
              ),
              _BottomNavIcon(
                icon: isLoading ? Icons.close_rounded : Icons.refresh_rounded,
                label: isLoading ? 'Stop' : 'Reload',
                onTap: onReload,
              ),
              _BottomNavIcon(
                icon: Icons.history_rounded,
                label: 'History',
                onTap: onHistory,
              ),
              _BottomNavIcon(
                icon: Icons.bookmark_border_rounded,
                label: 'Bookmarks',
                onTap: onBookmarks,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(23),
                gradient: isStartPage
                    ? LinearGradient(
                        colors: [
                          AppTheme.onSurface(context).withAlpha(20),
                          AppTheme.onSurface(context).withAlpha(20),
                        ],
                      )
                    : const LinearGradient(
                        colors: [AppTheme.neonPurple, AppTheme.neonCyan],
                      ),
                boxShadow: isStartPage
                    ? []
                    : [
                        BoxShadow(
                          color: AppTheme.neonCyan.withAlpha(60),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ElevatedButton.icon(
                onPressed: isStartPage || isFetchingStreams
                    ? null
                    : onDownloadPressed,
                icon: Icon(
                  isFetchingStreams
                      ? Icons.hourglass_top_rounded
                      : Icons.download_rounded,
                  size: 20,
                  color: isStartPage
                      ? AppTheme.disabled(context)
                      : AppTheme.onSurface(context),
                ),
                label: Text(
                  isFetchingStreams ? 'Wait...' : 'Download',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isStartPage
                        ? AppTheme.disabled(context)
                        : AppTheme.onSurface(context),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledForegroundColor: AppTheme.disabled(context),
                  disabledBackgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomNavIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.onSurface(context).withAlpha(179), size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.dimText(context),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
