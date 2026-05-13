import 'package:flutter/material.dart';

const _kNeonCyan = Color(0xFF00CEC9);
const _kNeonPurple = Color(0xFF6C5CE7);
const _kSurface = Color(0xFF1E1E2C);
const _kDeepBg = Color(0xFF141422);
const _kTextDim = Color(0x99E0E0E0);

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _SectionTitle(title: 'General'),
                _SettingsTile(
                  icon: Icons.folder_outlined,
                  title: 'Storage Location',
                  subtitle: 'Documents/MunDown',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.high_quality_outlined,
                  title: 'Default Quality',
                  subtitle: 'Highest available',
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                _SectionTitle(title: 'Cache'),
                _SettingsTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear Cache',
                  subtitle: 'Free up temporary storage',
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
                  subtitle: '0.1.0+1',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      color: _kDeepBg,
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [_kNeonPurple, _kNeonCyan],
            ).createShader(rect),
            child: const Icon(Icons.settings_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 10),
          const Text('Settings',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cache',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: const Text('This will remove all temporary files.',
            style: TextStyle(color: _kTextDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _kTextDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Clear', style: TextStyle(color: _kNeonCyan)),
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
          color: _kNeonCyan.withAlpha(180),
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
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: _kNeonPurple, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style:
                              const TextStyle(color: _kTextDim, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white24, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
