# network_speed_meter

Flutter plugin that surfaces real-time Android network throughput using `TrafficStats`, with optional foreground-service monitoring and notification updates.

## Features
- TrafficStats-based download/upload/total bytes-per-second sampling
- Stream-based updates with strongly typed models
- Configurable interval (default 1000ms) and basic validation
- Optional foreground service with ongoing notification updates
- Formatting helpers for B/s, KB/s, MB/s, GB/s
- Android 14 foreground service type (`dataSync`) declaration

## Platform support
Android only. iOS/web/desktop are not implemented.

## Installation
Add to your `pubspec.yaml`:
```yaml
dependencies:
  network_speed_meter: ^0.1.0
```

## Android setup
- Minimum SDK: 21 (Lollipop). TrafficStats is available earlier; 21 is a modern floor and matches current Flutter defaults.
- Compile/target SDK: 35 (Android 15 ready).
- Required permissions in your app manifest (plugin declares them, but you may prefer to own them):
  ```xml
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" tools:targetApi="33" />
  ```
- Foreground service entry (already included in the plugin manifest):
  ```xml
  <service
      android:name="com.networkspeedmeter.network_speed_meter.NetworkSpeedForegroundService"
      android:exported="false"
      android:foregroundServiceType="dataSync" />
  ```
- Android 13+: request `POST_NOTIFICATIONS` at runtime before enabling foreground notifications.
- Android 14+: verify your use of `FOREGROUND_SERVICE_DATA_SYNC` complies with Play policies.

## Usage
```dart
import 'package:network_speed_meter/network_speed_meter.dart';

Future<void> start() async {
  const config = NetworkSpeedConfig(
    interval: Duration(seconds: 1),
    enableForegroundService: false,
    showNotification: true,
    notificationTitle: 'Network speed',
    notificationContent: 'Monitoring traffic...',
  );
  await networkSpeedMeter.startMonitoring(config: config);

  networkSpeedMeter.speedStream.listen((snapshot) {
    print('Down: ${snapshot.formattedDownload}, '
        'Up: ${snapshot.formattedUpload}, '
        'Total: ${snapshot.formattedTotal}');
  });
}

Future<void> stop() => networkSpeedMeter.stopMonitoring();
```

### Foreground service mode
Enable `enableForegroundService` in `NetworkSpeedConfig` to keep monitoring in the background with an ongoing notification. The service:
- Uses foreground service type `dataSync`
- Updates the notification with current speeds
- Broadcasts updates back to Flutter via the event channel

### Formatting helpers
`SpeedFormatter` converts byte-per-second values into readable strings:
```dart
speedFormatter.format(1024); // "1.0 KB/s"
speedFormatter.format(5 * 1024 * 1024); // "5.0 MB/s"
```

## Example app
`example/lib/main.dart` mirrors the Play Store reference app with four tabs:
- Dashboard: live download/upload/total cards, chart, controls, session stats
- Usage: daily counters, session usage, peaks, notification preview
- History: per-session archive with averages and peaks
- Settings: interval, auto-start, foreground/notification toggles and demo reset

Run it from `example/` with `flutter run -d android`.

## Testing
- Dart unit tests: `flutter test` (formatter, config validation, platform wiring)
- Android instrumentation scaffold: `android/src/androidTest/...` contains a smoke test placeholder; extend with TrafficStats monitor tests using an emulator.

## Manual test checklist
- Start monitoring in app, observe steady stream updates
- Validate first sample does not spike (baseline is skipped)
- Stop monitoring: stream stops and state resets
- Toggle foreground mode: notification appears with speeds, background updates continue
- Android 13+: request notification permission and confirm notification shows
- Android 14+: verify service starts with `dataSync` type and no policy warnings

## Limitations and notes
- TrafficStats reports per-device counters; OEM status-bar values may differ because of smoothing/rounding.
- Values represent throughput since the previous sample, not latency or server-side speed tests.
- Foreground service behavior depends on OEM policies and battery optimizations; document requirements for your app.
- Plugin is Android-only; other platforms throw unimplemented errors.

## Differences from reference implementation
- Rebuilt as a Flutter plugin (not a standalone Android app) with MethodChannel for control and EventChannel for streaming.
- Kotlin-based monitor and optional foreground service with structured callbacks instead of UI-bound logic.
- Strongly typed Dart API/models, formatting helpers, and unit tests for core utilities.
- Configurable interval and notification metadata provided from Flutter rather than hard-coded.
- Conceptually informed by TrafficStats-based monitoring in https://github.com/thanush0/InternetSpeedMeter, but fully refactored into plugin architecture with new code.

## Commands
- Create/update dependencies: `flutter pub get`
- Run tests: `flutter test`
- Run example (Android): `flutter run -d android` from `example/`
