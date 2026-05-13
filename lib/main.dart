import 'package:flutter/material.dart';

import 'core/themes/app_theme.dart';
import 'features/home/presentation/pages/main_scaffold.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await di.init();

  runApp(const MunDownApp());
}

class MunDownApp extends StatelessWidget {
  const MunDownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MunDown',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScaffold(),
    );
  }
}
