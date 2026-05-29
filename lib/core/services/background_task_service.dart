import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import '../../../../core/utils/file_manager.dart';
import '../../../../features/downloader/domain/entities/download_metadata.dart';
import '../../../../features/downloader/data/models/download_metadata_model.dart';

/// Top-level function that will be called in the background isolate.
// Must be a top-level function (not a method of a class) and annotated with @pragma.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'downloadFromBackground':
        // Extract parameters from inputData
        final url = inputData?['url'] as String?;
        final metadataJson = inputData?['metadata'] as String?;
        final savePath = inputData?['savePath'] as String?;

        if (url == null || savePath == null) {
          return Future.value(false);
        }

        DownloadMetadata? metadata;
        if (metadataJson != null && metadataJson.isNotEmpty) {
          try {
            final jsonMap = jsonDecode(metadataJson) as Map<String, dynamic>;
            final metadataModel = DownloadMetadataModel.fromJson(jsonMap);
            metadata = metadataModel;
          } catch (e) {
            // If metadata is invalid, continue without it
            metadata = null;
          }
        }

        // Download the file using Dio, resuming if a partial file exists
        try {
          final dio = Dio();
          final file = File(savePath);

          // Check if we have a partial file to resume from
          if (await file.exists()) {
            final downloadedBytes = await file.length();
            // Set range header to resume download
            dio.options.headers[HttpHeaders.rangeHeader] = 'bytes=$downloadedBytes-';
          }

          await dio.download(url, savePath);

          // Save metadata if we have it
          if (metadata != null) {
            await FileManager.saveMetadata(savePath, metadata);
          }

          // Return success
          return Future.value(true);
        } catch (e) {
          // In case of error, return false
          return Future.value(false);
        }

      default:
        return Future.value(false);
    }
  });
}

/// Service to handle background tasks using workmanager.
class BackgroundTaskService {
  BackgroundTaskService._();

  /// Initializes the background task service.
  /// This must be called before runApp().
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Workmanager().initialize(
      callbackDispatcher, // The top-level function we defined above
    );
  }

  /// Registers a one-off background download task.
  /// [url] is the URL to download.
  /// [metadata] is optional metadata to save with the file.
  /// [savePath] is the full path where the file should be saved.
  static Future<void> registerDownloadTask({
    required String url,
    DownloadMetadata? metadata,
    required String savePath,
  }) async {
    final metadataJson = metadata != null
        ? jsonEncode(DownloadMetadataModel.fromEntity(metadata).toJson())
        : null;

    await Workmanager().registerOneOffTask(
      'downloadFromBackground', // The task name must match the case in callbackDispatcher
      'downloadFromBackground', // Task name
      inputData: {
        'url': url,
        'metadata': metadataJson,
        'savePath': savePath,
      },
      backoffPolicy: BackoffPolicy.exponential,
    );
  }
}