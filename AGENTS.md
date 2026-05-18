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
- WebView: webview_flutter ^4.13.0 + webview_flutter_wkwebview + webview_flutter_android
- YouTube extraction: youtube_explode_dart ^2.3.9
- Video Player: media_kit ^1.1.11 + media_kit_video ^1.2.5 + media_kit_libs_video ^1.0.5
- Media Muxing: ffmpeg_kit_flutter_new ^4.1.0
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
3. **Files** — file manager with video playback and SharedPreferences vault lock (FilesBloc)
4. **Settings** — theme selector (dark/light/system), biometric lock, cache clearing
5. **Home** — MainScaffold with 4-tab bottom navigation between all features

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
- Theme persisted via SharedPreferences key: 'theme_mode' (string values: 'dark', 'light', 'system')
- Theme applied via MunDownApp.of(context)?.setThemeMode(ThemeMode)
- Access theme: Theme.of(context).colorScheme / textTheme

### Navigation
- No router package — using Navigator.push / Navigator.pop directly
- MainScaffold manages bottom nav index with setState (exception to BLoC rule, UI-only state)

### Networking & Downloads
- All HTTP via Dio instance registered in sl
- YouTube downloads via YouTubeExtractor (youtube_explode_dart wrapper)
- File paths via path_provider + FileManager utility (Android saves to public Downloads/MunDown folder, iOS to app documents)
- Always check connectivity via NetworkInfo before network calls
- Download requests include YouTube headers (User-Agent, Referer, Origin, Accept) to avoid anti-bot blocking
- 3-attempt retry with exponential backoff (1s, 2s, 4s) for transient network failures

---

## DO NOT
- Add new state management libraries (no Riverpod, no Provider)
- Add Firebase or any backend (app is fully local/offline)
- Hardcode colors, strings, or timeouts (use AppTheme / AppConstants)
- Put logic in widgets — use BLoC events
- Skip registering new services in injection_container.dart
- Use isar (removed from project — use shared_preferences or files)
- Add navigation packages (no GoRouter, no AutoRoute)
- Recreate the Downloads History feature — it was intentionally deleted

---

## Key Constants (AppConstants in core/utils/constants.dart)
- AppConstants.baseUrl
- AppConstants.connectionTimeout
- AppConstants.receiveTimeout

---

## App Entry Point
main() → MediaKit.ensureInitialized() → di.init() → SharedPreferences load theme ('theme_mode') → MunDownApp(initialThemeMode)

---

## Recent Changes

### DELETED Features
- **Downloads History** — entire `lib/features/downloads_history/` directory and all DI registrations were removed. Do not recreate.

### Dependencies Added
- `media_kit` ^1.1.11 (libmpv-based video/audio player)
- `media_kit_video` ^1.2.5
- `media_kit_libs_video` ^1.0.5
- `ffmpeg_kit_flutter_new` ^4.1.0 (video+audio muxing for high-res YouTube downloads)
- `webview_flutter_wkwebview` (inline media playback on iOS)
- `webview_flutter_android` (media playback without user gesture on Android)

### Dependencies Removed
- `video_player` ^2.9.3
- `chewie` ^1.8.5

### Theme Changes
- Dark Mode toggle replaced with a 3-option Theme selector (Dark / Light / System)
- Persisted in SharedPreferences with key `'theme_mode'` (string: 'dark' | 'light' | 'system')
- Old `'dark_mode'` bool key is automatically migrated to `'theme_mode'` on first run
- `MunDownAppState.setThemeMode(ThemeMode)` replaces the old `toggleTheme()`
- `MaterialApp.themeMode` receives `ThemeMode.system` when device-following is selected

### Video Player
- `VideoPlayerView` completely rewritten using `media_kit` (`Player` + `VideoController`)
- Verifies file exists and is non-empty before initialization
- Waits for valid duration before showing controls (eliminates "Unable to play this file")
- Uses `AdaptiveVideoControls` for modern built-in controls (play/pause, seek bar, fullscreen, duration)
- `AudioSession` remains configured for background playback

### Quality Fetching
- `QualityBottomSheet` now accepts `Future<List<StreamOption>>` instead of a pre-computed list
- Sheet opens immediately with skeleton tiles while streams fetch in the background
- Download button is disabled until streams arrive and a selection is made
- No more blocking "Fetching qualities..." delay

### Complete Quality List (144p–1080p+)
- `youtube_extractor.dart` now extracts both `muxed` (video+audio) and `videoOnly` streams
- Results deduplicated by resolution; sorted ascending 144p → highest available
- Resolutions above 720p are `needsMux=true` with a paired `audioUrl`
- File sizes shown for every option (combined size for muxed entries)
- Audio-only streams shown below video, highest bitrate first

### Download Reliability
- `DownloaderRemoteDataSourceImpl` sends YouTube headers with every request
- 3-attempt retry with exponential backoff (1s, 2s, 4s) on transient `DioException`
- Real error messages including HTTP status code (e.g. "HTTP 403 — Forbidden")
- Cancelled downloads are emitted as `Paused`, not `Failed`

### High-Resolution Downloads (>720p)
- When a `StreamOption.needsMux == true` is selected:
  1. Video-only stream downloads to temp file
  2. Paired audio-only stream downloads to temp file
  3. `ffmpeg -c:v copy -c:a aac` merges them into the final mp4
  4. Temp files are cleaned up regardless of success/failure
- Progress reported as combined video + audio bytes

### Bottom Navigation
- Reduced to **4 tabs only**: Browser, Downloads, Library, Settings
- History tab removed entirely
- Compact sizing: icon 20px, label 10px, vertical padding 4px, indicator 2px

### UI Proportions
- All page headers (Browser brand, Downloads, Settings) reduced in padding, icon size, and title font size
- Consistent compact header style across the app

### iOS Info.plist
- Added `NSAppTransportSecurity > NSAllowsArbitraryLoads = true` to allow WKWebView and Dio to access signed googlevideo URLs
