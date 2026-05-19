import 'package:flutter/material.dart';
import '../../../../core/themes/app_theme.dart';

class BrowserBrandHeader extends StatelessWidget {
  const BrowserBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppTheme.neonPurple, AppTheme.neonCyan],
            ).createShader(rect),
            child: const Icon(
              Icons.language_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Browser',
            style: TextStyle(
              color: AppTheme.onSurface(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
