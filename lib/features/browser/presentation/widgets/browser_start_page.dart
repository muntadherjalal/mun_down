import 'package:flutter/material.dart';
import '../../../../core/themes/app_theme.dart';

class BrowserStartPage extends StatelessWidget {
  final TextEditingController urlBarController;
  final ValueChanged<String> onNavigate;

  const BrowserStartPage({
    super.key,
    required this.urlBarController,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background(context),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What do you want to download?',
            style: TextStyle(
              color: AppTheme.onSurface(context),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.neonCyan.withAlpha(80)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neonCyan.withAlpha(20),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: TextField(
                controller: urlBarController,
                decoration: InputDecoration(
                  hintText: 'Search or enter URL...',
                  hintStyle: TextStyle(
                    color: AppTheme.dimText(context),
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.neonCyan,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: TextStyle(
                  color: AppTheme.onSurface(context),
                  fontSize: 16,
                ),
                textInputAction: TextInputAction.go,
                onSubmitted: onNavigate,
              ),
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShortcutTile(
                icon: Icons.play_circle_fill_rounded,
                label: 'YouTube',
                color: Colors.redAccent,
                onTap: () => onNavigate('https://m.youtube.com'),
              ),
              _ShortcutTile(
                icon: Icons.music_note_rounded,
                label: 'TikTok',
                color: AppTheme.onSurface(context),
                onTap: () => onNavigate('https://www.tiktok.com'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShortcutTile(
                icon: Icons.camera_alt_rounded,
                label: 'Instagram',
                color: Colors.pinkAccent,
                onTap: () => onNavigate('https://www.instagram.com'),
              ),
              _ShortcutTile(
                icon: Icons.cloud_rounded,
                label: 'SoundCloud',
                color: Colors.orangeAccent,
                onTap: () => onNavigate('https://m.soundcloud.com'),
              ),
            ],
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.onSurface(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
