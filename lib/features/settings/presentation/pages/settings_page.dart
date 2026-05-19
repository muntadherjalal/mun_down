import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _cacheSize = 'Calculating...';

  bool _autoPasteUrl = true;
  bool _wifiOnly = false;
  bool _compactList = false;
  bool _pipEnabled = true;

  @override
  void initState() {
    super.initState();
    _calculateCache();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _pipEnabled = prefs.getBool('pip_enabled') ?? true;
        _autoPasteUrl = prefs.getBool('auto_paste') ?? true;
        _wifiOnly = prefs.getBool('wifi_only') ?? false;
        _compactList = prefs.getBool('compact_list') ?? false;
      });
    }
  }

  Future<void> _togglePip(bool value) async {
    setState(() => _pipEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pip_enabled', value);
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
      try {
        await WebViewCookieManager().clearCookies();
      } catch (_) {}
      await _calculateCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.surface(context),
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

  // ── Theme selector bottom sheet ───────────────────────────

  void _showThemeSelector(BuildContext context) {
    final appState = MunDownApp.of(context);
    final currentMode = appState?.themeMode ?? ThemeMode.system;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.background(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.onSurface(ctx).withAlpha(40),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose Theme',
                style: TextStyle(
                  color: AppTheme.onSurface(ctx),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _ThemeOption(
                icon: Icons.dark_mode_rounded,
                label: 'Dark Mode',
                isSelected: currentMode == ThemeMode.dark,
                onTap: () {
                  appState?.setThemeMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
              _ThemeOption(
                icon: Icons.light_mode_rounded,
                label: 'Light Mode',
                isSelected: currentMode == ThemeMode.light,
                onTap: () {
                  appState?.setThemeMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
              _ThemeOption(
                icon: Icons.phone_android_rounded,
                label: 'System Default',
                isSelected: currentMode == ThemeMode.system,
                onTap: () {
                  appState?.setThemeMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _themeSubtitle(ThemeMode? mode) {
    return switch (mode) {
      ThemeMode.dark => 'Dark theme active',
      ThemeMode.light => 'Light theme active',
      ThemeMode.system => 'Follows device theme',
      null => 'Follows device theme',
    };
  }

  @override
  Widget build(BuildContext context) {
    final appState = MunDownApp.of(context);
    final currentMode = appState?.themeMode ?? ThemeMode.system;

    return Scaffold(
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
                  _SettingsSwitch(
                    icon: Icons.picture_in_picture_alt_rounded,
                    title: 'Picture-in-Picture (PiP)',
                    subtitle: 'Continue playing video in background',
                    value: _pipEnabled,
                    onChanged: _togglePip,
                  ),
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: _themeSubtitle(currentMode),
                    onTap: () => _showThemeSelector(context),
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
                        SnackBar(
                          backgroundColor: AppTheme.surface(context),
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
                        SnackBar(
                          backgroundColor: AppTheme.surface(context),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppTheme.neonPurple, AppTheme.neonCyan],
            ).createShader(rect),
            child: Icon(
              Icons.settings_rounded,
              color: AppTheme.onSurface(context),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Settings',
            style: TextStyle(
              color: AppTheme.onSurface(context),
              fontSize: 16,
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
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Cache',
          style: TextStyle(color: AppTheme.onSurface(context), fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will remove all temporary files and WebView cookies.',
          style: TextStyle(color: AppTheme.dimText(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.dimText(context)),
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
        color: AppTheme.glass(context),
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
                        style: TextStyle(
                          color: AppTheme.onSurface(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.dimText(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.onSurface(context).withAlpha(40),
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
        color: AppTheme.glass(context),
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
                        style: TextStyle(
                          color: AppTheme.onSurface(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.dimText(context),
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
                  inactiveThumbColor: AppTheme.dimText(context),
                  inactiveTrackColor: AppTheme.onSurface(context).withAlpha(20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppTheme.neonCyan.withAlpha(20) : AppTheme.surface(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.neonCyan : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.neonPurple, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.onSurface(context) : AppTheme.onSurface(context).withAlpha(220),
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded,
                    color: AppTheme.neonCyan, size: 22)
              else
                const SizedBox(width: 22),
            ],
          ),
        ),
      ),
    );
  }
}
