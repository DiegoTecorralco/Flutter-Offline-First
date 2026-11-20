import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';
import 'sync_service.dart';

const backgroundTaskName = 'bidirectionalSync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await Firebase.initializeApp();
      await SyncService.instance.sync();
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> configureBackgroundSync() async {
  await Workmanager().initialize(callbackDispatcher);
  // Se agenda un trabajo one-off con restriccion de red. Android decide el momento.
  await Workmanager().registerOneOffTask('offline-first-sync', backgroundTaskName,
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep);
}

Future<void> scheduleRetry() async {
  await Workmanager().registerOneOffTask('offline-first-sync', backgroundTaskName,
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.replace);
}
