import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'core/network/network_info.dart';
import 'core/utils/constants.dart';
import 'core/utils/youtube_extractor.dart';
import 'features/downloader/data/datasources/downloader_remote_data_source.dart';
import 'features/downloader/data/repositories/downloader_repository_impl.dart';
import 'features/downloader/domain/repositories/downloader_repository.dart';
import 'features/downloader/presentation/bloc/downloader_bloc.dart';
import 'features/files/data/datasources/files_local_data_source.dart';
import 'features/files/data/repositories/files_repository_impl.dart';
import 'features/files/domain/repositories/files_repository.dart';
import 'features/files/domain/usecases/get_locked_files_usecase.dart';
import 'features/files/domain/usecases/toggle_file_lock_usecase.dart';
import 'features/files/presentation/bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global service locator instance.
final sl = GetIt.instance;

/// Initializes all dependencies.
///
/// Call this once in [main] before [runApp].
Future<void> init() async {
  //──────────────────────────────────────────────────────────
  // Core
  //──────────────────────────────────────────────────────────
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());

  sl.registerLazySingleton<Dio>(() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout:
          const Duration(milliseconds: AppConstants.connectionTimeout),
      receiveTimeout:
          const Duration(milliseconds: AppConstants.receiveTimeout),
    ));
    return dio;
  });

  sl.registerLazySingleton<YouTubeExtractor>(() => YouTubeExtractor());

  //──────────────────────────────────────────────────────────
  // Features — Downloader
  //──────────────────────────────────────────────────────────

  // Data sources
  sl.registerLazySingleton<DownloaderRemoteDataSource>(
    () => DownloaderRemoteDataSourceImpl(
      dio: sl<Dio>(),
      extractor: sl<YouTubeExtractor>(),
    ),
  );

  // Repositories
  sl.registerLazySingleton<DownloaderRepository>(
    () => DownloaderRepositoryImpl(remoteDataSource: sl()),
  );

  // BLoC
  sl.registerFactory<DownloaderBloc>(
    () => DownloaderBloc(
      repository: sl(),
      networkInfo: sl(),
    ),
  );

  //──────────────────────────────────────────────────────────
  // Features — Files
  //──────────────────────────────────────────────────────────
  // Data sources
  sl.registerLazySingleton<FilesLocalDataSource>(
    () => FilesLocalDataSourceImpl(sharedPreferences: sl()),
  );

  // Repositories
  sl.registerLazySingleton<FilesRepository>(
    () => FilesRepositoryImpl(localDataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetLockedFilesUseCase(sl()));
  sl.registerLazySingleton(() => ToggleFileLockUseCase(sl()));

  // BLoC
  sl.registerFactory(
    () => FilesBloc(
      getLockedFiles: sl(),
      toggleFileLock: sl(),
    ),
  );

}
