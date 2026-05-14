# Project: mun_down
# A Video & Audio Downloader Flutter App
# Version: 1.5.0+1

---

## App Purpose
Mobile/desktop app that lets users browse the web via built-in WebView,
extract and download YouTube videos/audio in multiple qualities,
manage downloaded files, and play videos — with biometric lock and theme support.

---

## Tech Stack
- Flutter 3.x / Dart SDK ^3.11.1
- State Management: flutter_bloc ^9.1.1 + equatable ^2.0.7 (BLoC pattern ONLY)
- Dependency Injection: get_it ^8.0.3 (service locator via sl in injection_container.dart)
- Networking: dio ^5.8.0+1
- Local Storage: shared_preferences ^2.3.5
- WebView: webview_flutter ^4.13.0
- YouTube extraction: youtube_explode_dart ^2.3.9
- Video Player: video_player ^2.9.3 + chewie ^1.8.5
- Biometric Auth: local_auth ^2.3.0
- File Sharing: share_plus ^10.1.4
- File Opening: open_filex ^4.5.0
- Connectivity: connectivity_plus ^6.1.1
- Audio Session: audio_session ^0.2.3
- Permissions: permission_handler ^11.3.1
- Path: path_provider ^2.1.5
- Code gen: build_runner ^2.4.15

---

## Architecture — Clean Architecture (STRICT)

lib/
  features/
    browser/
      domain/entities/
      presentation/pages/
      presentation/widgets/
    downloader/
      data/datasources/
      data/models/
      data/repositories/
      domain/entities/
      domain/repositories/
      domain/usecases/
      presentation/bloc/
      presentation/pages/
      presentation/widgets/
    downloads_history/
      data/datasources/
      data/models/
      data/repositories/
      domain/entities/
      domain/repositories/
      domain/usecases/
      presentation/bloc/
      presentation/pages/
      presentation/widgets/
    files/
      data/datasources/
      data/repositories/
      domain/repositories/
      domain/usecases/
      presentation/bloc/
      presentation/pages/
      presentation/widgets/
    home/
      presentation/pages/
    settings/
      presentation/pages/
  core/
    errors/        # exceptions.dart, failures.dart
    network/       # network_info.dart
    themes/        # app_theme.dart (AppTheme.lightTheme / AppTheme.darkTheme)
    utils/         # constants.dart, file_manager.dart, youtube_extractor.dart, biometric_helper.dart
    widgets/       # neon_arc_painter.dart
  injection_container.dart   # all DI setup — register new deps here
  main.dart

---

## Existing Features
1. **Browser** — WebView-based browser (browser_page.dart, components in widgets/)
2. **Downloader** — YouTube + generic URL downloader with quality selection (DownloaderBloc)
3. **Downloads History** — history of past downloads (Domain, Data, and BLoC implemented. UI pending)
4. **Files** — file manager with video playback and SharedPreferences vault lock (FilesBloc)
5. **Settings** — dark/light theme toggle, biometric lock
6. **Home** — MainScaffold with bottom navigation between all features

---

## Strict Code Rules

### State Management
- Use BLoC ONLY — never setState for business logic, never Provider, never Riverpod
- Every feature's state lives in presentation/bloc/
- BLoC files: feature_bloc.dart, feature_event.dart, feature_state.dart
- Always export via barrel file bloc.dart in the bloc folder

### Dependency Injection
- All dependencies registered in injection_container.dart using sl (GetIt instance)
- Use registerLazySingleton for services/repos/datasources/usecases
- Use registerFactory for BLoCs
- Never instantiate services directly in widgets — always inject via sl

### Folder & File Rules
- Every new feature must follow the same clean architecture folder structure
- Use barrel files (e.g. bloc.dart, pages.dart, widgets.dart) for exports
- Separate widget into its own file if it exceeds 80 lines
- No business logic inside widgets or pages — delegate to BLoC

### Theming
- All colors from AppTheme ONLY — never hardcode Color values
- Theme persisted via SharedPreferences key: 'dark_mode' (bool)
- Theme toggled via MunDownApp.of(context)?.toggleTheme()
- Access theme: Theme.of(context).colorScheme / textTheme

### Navigation
- No router package — using Navigator.push / Navigator.pop directly
- MainScaffold manages bottom nav index with setState (exception to BLoC rule, UI-only state)

### Networking & Downloads
- All HTTP via Dio instance registered in sl
- YouTube downloads via YouTubeExtractor (youtube_explode_dart wrapper)
- File paths via path_provider + FileManager utility (Android saves to public Downloads/MunDown folder, iOS to app documents)
- Always check connectivity via NetworkInfo before network calls

---

## DO NOT
- Add new state management libraries (no Riverpod, no Provider)
- Add Firebase or any backend (app is fully local/offline)
- Hardcode colors, strings, or timeouts (use AppTheme / AppConstants)
- Put logic in widgets — use BLoC events
- Skip registering new services in injection_container.dart
- Use isar (removed from project — use shared_preferences or files)
- Add navigation packages (no GoRouter, no AutoRoute)

---

## Key Constants (AppConstants in core/utils/constants.dart)
- AppConstants.baseUrl
- AppConstants.connectionTimeout
- AppConstants.receiveTimeout

---

## App Entry Point
main() → di.init() → SharedPreferences load theme → MunDownApp(initialThemeMode)