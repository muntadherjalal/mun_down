import 'dart:io';

void main() {
  final files = [
    'lib/features/downloader/presentation/pages/downloader_page.dart',
    'lib/features/downloader/presentation/pages/downloads_page.dart',
  ];

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;

    String content = file.readAsStringSync();

    // Remove constants
    content = content.replaceAll(RegExp(r'const _kNeonCyan = Color\(0xFF00CEC9\);.*\n?'), '');
    content = content.replaceAll(RegExp(r'const _kNeonPurple = Color\(0xFF6C5CE7\);.*\n?'), '');
    content = content.replaceAll(RegExp(r'const _kSurface = Color\(0xFF1E1E2C\);.*\n?'), '');
    content = content.replaceAll(RegExp(r'const _kDeepBg = Color\(0xFF141422\);.*\n?'), '');
    content = content.replaceAll(RegExp(r'const _kErrorRed = Color\(0xFFFF6B6B\);.*\n?'), '');
    content = content.replaceAll(RegExp(r'const _kTextDim = Color\(0x99E0E0E0\);.*\n?'), '');
    content = content.replaceAll(RegExp(r'const _kGlassWhite = Color\(0x14FFFFFF\);.*\n?'), '');

    // Replace usages
    content = content.replaceAll('_kNeonCyan', 'AppTheme.kNeonCyan');
    content = content.replaceAll('_kNeonPurple', 'AppTheme.kNeonPurple');
    content = content.replaceAll('_kSurface', 'AppTheme.kSurface');
    content = content.replaceAll('_kDeepBg', 'AppTheme.kDeepBg');
    content = content.replaceAll('_kErrorRed', 'AppTheme.kErrorRed');
    content = content.replaceAll('_kTextDim', 'AppTheme.kTextDim');
    content = content.replaceAll('_kGlassWhite', 'AppTheme.kGlassWhite');

    // Remove _NeonArcPainter class
    content = content.replaceAll(RegExp(r'class _NeonArcPainter extends CustomPainter \{[\s\S]*?\}\s*$'), '');

    // Add imports
    if (!content.contains('app_theme.dart')) {
      content = content.replaceFirst(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport '../../../../core/theme/app_theme.dart';\nimport '../../../../core/widgets/neon_arc_painter.dart';"
      );
    }
    
    // Replace _NeonArcPainter with NeonArcPainter
    content = content.replaceAll('_NeonArcPainter', 'NeonArcPainter');

    file.writeAsStringSync(content);
  }
}
