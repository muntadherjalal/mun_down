import 'package:shared_preferences/shared_preferences.dart';

abstract class FilesLocalDataSource {
  Future<Set<String>> getLockedFiles();
  Future<void> toggleFileLock(String filePath);
}

class FilesLocalDataSourceImpl implements FilesLocalDataSource {
  final SharedPreferences sharedPreferences;
  static const String _lockedFilesKey = 'LOCKED_FILES';

  FilesLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<Set<String>> getLockedFiles() async {
    final lockedFilesList = sharedPreferences.getStringList(_lockedFilesKey) ?? [];
    return lockedFilesList.toSet();
  }

  @override
  Future<void> toggleFileLock(String filePath) async {
    final lockedFiles = await getLockedFiles();
    if (lockedFiles.contains(filePath)) {
      lockedFiles.remove(filePath);
    } else {
      lockedFiles.add(filePath);
    }
    await sharedPreferences.setStringList(_lockedFilesKey, lockedFiles.toList());
  }
}
