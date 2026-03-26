import 'package:meta/meta.dart';

/// Configuration for network speed monitoring.
@immutable
class NetworkSpeedConfig {
  /// Creates a new configuration.
  const NetworkSpeedConfig({
    this.interval = const Duration(seconds: 1),
    this.enableForegroundService = false,
    this.showNotification = true,
    this.notificationTitle = 'Network speed monitor',
    this.notificationContent = 'Monitoring traffic in the background',
  });

  /// Interval between TrafficStats samples.
  final Duration interval;

  /// Whether to start monitoring in a foreground service.
  final bool enableForegroundService;

  /// Whether the foreground service should display a persistent notification.
  final bool showNotification;

  /// Notification title when foreground monitoring is enabled.
  final String notificationTitle;

  /// Notification content when foreground monitoring is enabled.
  final String notificationContent;

  /// Validates that the configuration meets plugin constraints.
  void validate() {
    if (interval.inMilliseconds < 200) {
      throw ArgumentError.value(
        interval,
        'interval',
        'Interval must be at least 200ms to avoid noisy readings.',
      );
    }
    if (interval.inMinutes >= 10) {
      throw ArgumentError.value(
        interval,
        'interval',
        'Interval is too long for meaningful speed measurement.',
      );
    }
    if (notificationTitle.isEmpty) {
      throw ArgumentError.value(
        notificationTitle,
        'notificationTitle',
        'Notification title cannot be empty.',
      );
    }
    if (notificationContent.isEmpty) {
      throw ArgumentError.value(
        notificationContent,
        'notificationContent',
        'Notification content cannot be empty.',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'intervalMs': interval.inMilliseconds,
      'enableForegroundService': enableForegroundService,
      'showNotification': showNotification,
      'notificationTitle': notificationTitle,
      'notificationContent': notificationContent,
    };
  }

  NetworkSpeedConfig copyWith({
    Duration? interval,
    bool? enableForegroundService,
    bool? showNotification,
    String? notificationTitle,
    String? notificationContent,
  }) {
    return NetworkSpeedConfig(
      interval: interval ?? this.interval,
      enableForegroundService:
          enableForegroundService ?? this.enableForegroundService,
      showNotification: showNotification ?? this.showNotification,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationContent: notificationContent ?? this.notificationContent,
    );
  }
}
