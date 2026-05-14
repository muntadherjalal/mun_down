import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/download_history_item_model.dart';

abstract class DownloadsHistoryLocalDataSource {
  Future<List<DownloadHistoryItemModel>> getHistory();
  Future<void> addHistoryItem(DownloadHistoryItemModel item);
  Future<void> clearHistory();
}

const cachedDownloadsHistory = 'DOWNLOADS_HISTORY';

class DownloadsHistoryLocalDataSourceImpl implements DownloadsHistoryLocalDataSource {
  final SharedPreferences sharedPreferences;

  DownloadsHistoryLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<List<DownloadHistoryItemModel>> getHistory() {
    try {
      final jsonStringList = sharedPreferences.getStringList(cachedDownloadsHistory);
      if (jsonStringList != null) {
        return Future.value(jsonStringList
            .map((jsonString) => DownloadHistoryItemModel.fromJson(jsonDecode(jsonString)))
            .toList());
      } else {
        return Future.value([]);
      }
    } catch (e) {
      throw const CacheException(message: 'Failed to access SharedPreferences');
    }
  }

  @override
  Future<void> addHistoryItem(DownloadHistoryItemModel item) async {
    try {
      final historyList = await getHistory();
      // Add the new item at the beginning
      historyList.insert(0, item);
      final jsonStringList = historyList.map((model) => jsonEncode(model.toJson())).toList();
      await sharedPreferences.setStringList(cachedDownloadsHistory, jsonStringList);
    } catch (e) {
      throw const CacheException(message: 'Failed to access SharedPreferences');
    }
  }

  @override
  Future<void> clearHistory() async {
    try {
      await sharedPreferences.remove(cachedDownloadsHistory);
    } catch (e) {
      throw const CacheException(message: 'Failed to access SharedPreferences');
    }
  }
}
