import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';

import '../../../features/files/domain/entities/downloaded_file_info.dart';
import '../../../features/downloader/domain/entities/download_metadata.dart';
import '../../../features/downloader/data/models/download_metadata_model.dart';

/// Utility that scans the MunDown downloads directory.
class FileManager {
  FileManager._();

  /// Default download directory inside app documents.
  static const _folderName = 'MunDown';

  /// Returns the absolute path to the downloads directory.
  static Future<String> get downloadsPath async {
    String path;
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      path = '${dir!.path}/$_folderName';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/$_folderName';
    }

    final directory = Directory(path);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return path;
  }

  /// Scans the downloads directory and returns [DownloadedFileInfo]
  /// objects sorted by modification date (newest first).
  /// Uses Isolate.run() to prevent blocking the main thread.
  static Future<List<DownloadedFileInfo>> scanFiles() async {
    final path = await downloadsPath;

    return await Isolate.run<List<DownloadedFileInfo>>(() => _scanFilesIsolate(path));
  }

  /// Saves metadata to a sidecar JSON file next to the main file.
  static Future<void> saveMetadata(
    String filePath,
    DownloadMetadata metadata,
  ) async {
    try {
      final file = File('$filePath.json');
      await file.writeAsString(
        jsonEncode(DownloadMetadataModel.fromEntity(metadata).toJson()),
      );
    } catch (_) {}
  }

  /// Deletes the file at [path] and its metadata sidecar if present.
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        final jsonFile = File('$path.json');
        if (await jsonFile.exists()) {
          await jsonFile.delete();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }
}

List<DownloadedFileInfo> _scanFilesIsolate(String downloadsPath) {
  final dir = Directory(downloadsPath);

  if (!dir.existsSync()) return [];

  final entities = dir.listSync().whereType<File>().toList();

  final files = <DownloadedFileInfo>[];

  for (final file in entities) {
    final name = file.path.split(Platform.pathSeparator).last;

    if (name.endsWith('.json')) continue;

    final stat = file.statSync();
    final dot = name.lastIndexOf('.');
    final ext = dot != -1 ? name.substring(dot + 1).toLowerCase() : '';

    DownloadMetadata? metadata;
    final jsonFile = File('${file.path}.json');
    if (jsonFile.existsSync()) {
        try {
          final content = jsonFile.readAsStringSync();
          final jsonMap = jsonDecode(content) as Map<String, dynamic>;
          final metadataModel = DownloadMetadataModel.fromJson(jsonMap);
          metadata = metadataModel;
        } catch (_) {}
    }

    files.add(
      DownloadedFileInfo(
        path: file.path,
        name: name,
        extension: ext,
        sizeBytes: stat.size,
        modified: stat.modified,
        metadata: metadata,
      ),
    );
  }

  files.sort((a, b) => b.modified.compareTo(a.modified));

  return files;
}