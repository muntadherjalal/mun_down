import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/themes/app_theme.dart';
import 'core/utils/youtube_extractor.dart';
import 'features/home/presentation/pages/main_scaffold.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit (libmpv-based player)
  MediaKit.ensureInitialized();

  // Initialize dependency injection
  await di.init();

  // Load persisted theme preference (with one-time migration from legacy 'dark_mode' bool)
  final prefs = await SharedPreferences.getInstance();
  ThemeMode initialMode;
  final stored = prefs.getString('theme_mode');
  if (stored != null) {
    initialMode = _parseThemeMode(stored);
  } else if (prefs.containsKey('dark_mode')) {
    final isDark = prefs.getBool('dark_mode') ?? true;
    initialMode = isDark ? ThemeMode.dark : ThemeMode.light;
    await prefs.setString('theme_mode', _themeModeToString(initialMode));
  } else {
    initialMode = ThemeMode.system;
  }

  runApp(MunDownApp(initialThemeMode: initialMode));
}

String _themeModeToString(ThemeMode mode) => switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };

ThemeMode _parseThemeMode(String value) => switch (value) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };

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
      di.sl<YouTubeExtractor>().dispose();
    }
    super.didChangeAppLifecycleState(state);
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// Sets a specific theme mode and persists the choice.
  Future<void> setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _themeModeToString(mode));
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
