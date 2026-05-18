import 'package:flutter/material.dart';
import '../../../../core/themes/app_theme.dart';

class BrowserBrandHeader extends StatelessWidget {
  const BrowserBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.kDeepBg,
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(10), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.download_rounded,
            color: AppTheme.neonCyan,
            size: 18,
          ),
          const SizedBox(width: 6),
          const Text(
            'MunDown',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
