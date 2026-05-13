import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'core/network/network_info.dart';
import 'core/utils/constants.dart';
import 'features/downloader/data/datasources/downloader_remote_data_source.dart';
import 'features/downloader/data/repositories/downloader_repository_impl.dart';
import 'features/downloader/domain/repositories/downloader_repository.dart';
import 'features/downloader/presentation/bloc/downloader_bloc.dart';

/// Global service locator instance.
final sl = GetIt.instance;

/// Initializes all dependencies.
///
/// Call this once in [main] before [runApp].
Future<void> init() async {
  //──────────────────────────────────────────────────────────
  // Core
  //──────────────────────────────────────────────────────────
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());

  sl.registerLazySingleton<Dio>(() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout:
          const Duration(milliseconds: AppConstants.connectionTimeout),
      receiveTimeout:
          const Duration(milliseconds: AppConstants.receiveTimeout),
    ));
    // Add interceptors here (logging, auth, retry…).
    return dio;
  });

  //──────────────────────────────────────────────────────────
  // Features — Downloader
  //──────────────────────────────────────────────────────────

  // Data sources
  sl.registerLazySingleton<DownloaderRemoteDataSource>(
    () => DownloaderRemoteDataSourceImpl(dio: sl<Dio>()),
  );

  // Repositories
  sl.registerLazySingleton<DownloaderRepository>(
    () => DownloaderRepositoryImpl(remoteDataSource: sl()),
  );

  // BLoC — registered as Factory so a fresh instance is created each time
  // it is requested (each screen gets its own BLoC lifecycle).
  sl.registerFactory<DownloaderBloc>(
    () => DownloaderBloc(repository: sl()),
  );

  //──────────────────────────────────────────────────────────
  // Features — Downloads History
  //──────────────────────────────────────────────────────────
  // Data sources

  // Repositories

  // Use cases

  // BLoC
}
