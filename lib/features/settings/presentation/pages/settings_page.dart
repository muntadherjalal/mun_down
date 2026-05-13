import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ضفنا هاي المكتبة للحفظ
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/file_manager.dart';
import '../../../../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _storagePath = 'Loading...';
  String _cacheSize = 'Calculating...';

  bool _autoPasteUrl = true;
  bool _wifiOnly = false;
  bool _compactList = false;
  bool _pipEnabled = true; // متغير الـ PiP الجديد

  @override
  void initState() {
    super.initState();
    _loadPaths();
    _calculateCache();
    _loadPreferences(); // تحميل الإعدادات المحفوظة
  }

  // دالة تحميل تفضيلات المستخدم
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _pipEnabled = prefs.getBool('pip_enabled') ?? true; // الافتراضي شغال
        _autoPasteUrl = prefs.getBool('auto_paste') ?? true;
        _wifiOnly = prefs.getBool('wifi_only') ?? false;
        _compactList = prefs.getBool('compact_list') ?? false;
      });
    }
  }

  // دالة حفظ حالة الـ PiP
  Future<void> _togglePip(bool value) async {
    setState(() => _pipEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pip_enabled', value);
  }

  Future<void> _loadPaths() async {
    final path = await FileManager.downloadsPath;
    if (mounted) setState(() => _storagePath = path);
  }

  Future<void> _calculateCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalSize = 0;
      if (tempDir.existsSync()) {
        await for (final entity in tempDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
      if (mounted) {
        setState(() {
          if (totalSize < 1024) {
            _cacheSize = '$totalSize B';
          } else if (totalSize < 1024 * 1024) {
            _cacheSize = '${(totalSize / 1024).toStringAsFixed(1)} KB';
          } else {
            _cacheSize = '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cacheSize = 'Unknown');
    }
  }

  Future<void> _clearCache() async {
    try {
      // Clear app temporary directory
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        await for (final entity in tempDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }

      // Clear WebView cookies/cache
      try {
        await WebViewCookieManager().clearCookies();
      } catch (_) {}

      await _calculateCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.kSurface,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Cache cleared successfully',
              style: TextStyle(color: AppTheme.neonCyan, fontSize: 13),
            ),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Read current theme mode from the app state
    final appState = MunDownApp.of(context);
    final isDark = appState?.isDarkMode ?? true;

    return Scaffold(
      backgroundColor: AppTheme.kDeepBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  _SectionTitle(title: 'General'),
                  _SettingsTile(
                    icon: Icons.folder_outlined,
                    title: 'Storage Location',
                    subtitle: _storagePath,
                    onTap: () {},
                  ),
                  _SettingsSwitch(
                    icon: Icons.content_paste_rounded,
                    title: 'Auto-paste URL',
                    subtitle: 'From clipboard on startup',
                    value: _autoPasteUrl,
                    onChanged: (v) async {
                      setState(() => _autoPasteUrl = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('auto_paste', v);
                    },
                  ),
                  _SettingsSwitch(
                    icon: Icons.wifi_rounded,
                    title: 'WiFi Only Downloads',
                    subtitle: 'Pause downloads on cellular data',
                    value: _wifiOnly,
                    onChanged: (v) async {
                      setState(() => _wifiOnly = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('wifi_only', v);
                    },
                  ),
                  const SizedBox(height: 20),

                  _SectionTitle(title: 'Player & Appearance'),
                  // 🚀 زر الـ PiP انضاف هنا
                  _SettingsSwitch(
                    icon: Icons.picture_in_picture_alt_rounded,
                    title: 'Picture-in-Picture (PiP)',
                    subtitle: 'Continue playing video in background',
                    value: _pipEnabled,
                    onChanged: _togglePip,
                  ),
                  _SettingsSwitch(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    title: 'Dark Mode',
                    subtitle: isDark
                        ? 'Dark theme active'
                        : 'Light theme active',
                    value: isDark,
                    onChanged: (_) => appState?.toggleTheme(),
                  ),
                  _SettingsSwitch(
                    icon: Icons.view_headline_rounded,
                    title: 'Compact List View',
                    subtitle: 'Use smaller items in Library',
                    value: _compactList,
                    onChanged: (v) async {
                      setState(() => _compactList = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('compact_list', v);
                    },
                  ),
                  const SizedBox(height: 20),

                  _SectionTitle(title: 'Cache & Data'),
                  _SettingsTile(
                    icon: Icons.cleaning_services_outlined,
                    title: 'Clear Cache',
                    subtitle: _cacheSize,
                    onTap: () => _showClearCacheDialog(context),
                  ),
                  _SettingsTile(
                    icon: Icons.delete_sweep_outlined,
                    title: 'Clear Download History',
                    subtitle: 'Remove all history records',
                    onTap: () {},
                  ),
                  const SizedBox(height: 20),

                  _SectionTitle(title: 'About'),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Version',
                    subtitle: '1.5.0+1',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.code_rounded,
                    title: 'Source Code',
                    subtitle: 'github.com/MunDown',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppTheme.kSurface,
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            'Not implemented in MVP',
                            style: TextStyle(
                              color: AppTheme.neonPurple,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.star_border_rounded,
                    title: 'Rate App',
                    subtitle: 'Love MunDown? Let us know!',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppTheme.kSurface,
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            'Thank you!',
                            style: TextStyle(
                              color: AppTheme.neonCyan,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      color: AppTheme.kDeepBg,
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppTheme.neonPurple, AppTheme.neonCyan],
            ).createShader(rect),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear Cache',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'This will remove all temporary files and WebView cookies.',
          style: TextStyle(color: AppTheme.kTextDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.kTextDim),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCache();
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: AppTheme.neonCyan),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppTheme.neonCyan.withAlpha(180),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppTheme.kGlassWhite,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.neonPurple, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.kTextDim,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white24,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppTheme.kGlassWhite,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.neonPurple, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.kTextDim,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: AppTheme.neonCyan,
                  activeTrackColor: AppTheme.neonCyan.withAlpha(80),
                  inactiveThumbColor: AppTheme.kTextDim,
                  inactiveTrackColor: Colors.white12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
