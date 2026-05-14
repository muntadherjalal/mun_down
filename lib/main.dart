import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/themes/app_theme.dart';
import 'core/utils/youtube_extractor.dart';
import 'features/home/presentation/pages/main_scaffold.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await di.init();

  // Load persisted theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? true;

  runApp(MunDownApp(initialThemeMode: isDark ? ThemeMode.dark : ThemeMode.light));
}

class MunDownApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const MunDownApp({super.key, required this.initialThemeMode});

  /// Provides access to the app's theme controller from anywhere in the tree.
  static MunDownAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<MunDownAppState>();
  }

  @override
  State<MunDownApp> createState() => MunDownAppState();
}

class MunDownAppState extends State<MunDownApp> with WidgetsBindingObserver {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // App is being terminated, dispose resources
      di.sl<YouTubeExtractor>().dispose();
    }
    super.didChangeAppLifecycleState(state);
  }

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Toggles between dark and light mode and persists the choice.
  Future<void> toggleTheme() async {
    final newMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() => _themeMode = newMode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', newMode == ThemeMode.dark);
  }

  /// Sets a specific theme mode and persists the choice.
  Future<void> setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', mode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MunDown',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const MainScaffold(),
    );
  }
}
