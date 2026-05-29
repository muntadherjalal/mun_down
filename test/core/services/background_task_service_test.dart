import 'package:test/test.dart';

import 'package:mun_down/core/services/background_task_service.dart';

void main() {
  group('BackgroundTaskService', () {
    test('initialize is callable', () {
      expect(BackgroundTaskService.initialize, isNotNull);
    });

    test('registerDownloadTask is callable', () {
      expect(BackgroundTaskService.registerDownloadTask, isNotNull);
    });
  });
}