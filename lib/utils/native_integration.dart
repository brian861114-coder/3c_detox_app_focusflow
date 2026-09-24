import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeIntegration {
  static const MethodChannel _channel = MethodChannel('focus_flow/native');

  /// Invokes [method], logging instead of throwing when the platform side
  /// fails or does not exist (non-Android platforms, tests).
  static Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      debugPrint("Native call '$method' failed: ${e.message}");
    } on MissingPluginException {
      debugPrint("Native call '$method' is not available on this platform.");
    }
    return null;
  }

  // Request Usage Stats Permission (Android)
  static Future<void> requestUsageStatsPermission() => _invoke('requestUsageStatsPermission');

  // Request Overlay Permission (Android) for jumping back to app
  static Future<void> requestOverlayPermission() => _invoke('requestOverlayPermission');

  // Request Battery Optimization Ignore Permission (Android)
  static Future<void> requestBatteryOptimizationPermission() => _invoke('requestBatteryOptimizationPermission');

  // Get installed apps (Android)
  static Future<List<Map<String, String>>> getInstalledApps() async {
    final apps = await _invoke<List<dynamic>>('getInstalledApps');
    return apps?.map((e) => Map<String, String>.from(e as Map)).toList() ?? [];
  }

  /// Starts or updates the foreground blocking service.
  /// While [resting] the service keeps running but blocks nothing.
  static Future<void> startPersistentService(List<String> blockedApps, int remainingSeconds, {bool resting = false}) {
    return _invoke('startService', {
      'blockedApps': blockedApps,
      'remainingSeconds': remainingSeconds,
      'resting': resting,
    });
  }

  // Stop the persistent service
  static Future<void> stopPersistentService() => _invoke('stopService');
}
