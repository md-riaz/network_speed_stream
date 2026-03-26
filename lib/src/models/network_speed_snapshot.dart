import '../utils/speed_formatter.dart';

/// Represents a single network speed measurement.
class NetworkSpeedSnapshot {
  NetworkSpeedSnapshot({
    required this.downloadBytesPerSecond,
    required this.uploadBytesPerSecond,
    required this.totalBytesPerSecond,
    required this.timestamp,
    required this.fromForegroundService,
  });

  /// Download throughput in bytes per second.
  final int downloadBytesPerSecond;

  /// Upload throughput in bytes per second.
  final int uploadBytesPerSecond;

  /// Total throughput in bytes per second.
  final int totalBytesPerSecond;

  /// Time when the sample was taken.
  final DateTime timestamp;

  /// True when the sample originated from the foreground service.
  final bool fromForegroundService;

  /// Formats the download speed.
  String get formattedDownload =>
      const SpeedFormatter().format(downloadBytesPerSecond);

  /// Formats the upload speed.
  String get formattedUpload =>
      const SpeedFormatter().format(uploadBytesPerSecond);

  /// Formats the total speed.
  String get formattedTotal =>
      const SpeedFormatter().format(totalBytesPerSecond);

  factory NetworkSpeedSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return NetworkSpeedSnapshot(
      downloadBytesPerSecond: (map['downloadBps'] as num?)?.toInt() ?? 0,
      uploadBytesPerSecond: (map['uploadBps'] as num?)?.toInt() ?? 0,
      totalBytesPerSecond: (map['totalBps'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      fromForegroundService: map['fromForeground'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'downloadBps': downloadBytesPerSecond,
      'uploadBps': uploadBytesPerSecond,
      'totalBps': totalBytesPerSecond,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'fromForeground': fromForegroundService,
    };
  }
}
