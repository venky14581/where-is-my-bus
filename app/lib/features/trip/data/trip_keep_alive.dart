import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app running while a trip is active, with the screen off or
/// another app open.
abstract interface class TripKeepAlive {
  Future<void> start({required String title, required String text});
  Future<void> stop();
}

/// An Android foreground service of type `location`, shown as an ongoing
/// notification. Location keeps flowing to the app while it runs, without
/// asking for "allow all the time" permission. Does nothing on the web.
class ForegroundServiceKeepAlive implements TripKeepAlive {
  static const _serviceId = 3003;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> start({required String title, required String text}) async {
    if (!_supported) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'trip',
        channelName: 'Trip in progress',
        channelDescription: 'Shown while the bus location is being shared.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: true, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      // Without it the service still runs; only the notification is hidden.
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
    } else {
      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: title,
        notificationText: text,
      );
    }
  }

  @override
  Future<void> stop() async {
    if (_supported && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
