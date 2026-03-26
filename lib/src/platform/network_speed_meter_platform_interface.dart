import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../models/network_speed_config.dart';
import '../models/network_speed_exception.dart';
import '../models/network_speed_snapshot.dart';

/// Platform interface for network speed monitoring.
abstract class NetworkSpeedMeterPlatform extends PlatformInterface {
  NetworkSpeedMeterPlatform() : super(token: _token);

  static final Object _token = Object();

  static NetworkSpeedMeterPlatform _instance = _MethodChannelPlaceholder();

  /// Returns the currently configured platform instance.
  static NetworkSpeedMeterPlatform get instance => _instance;

  /// Sets the platform implementation.
  static set instance(NetworkSpeedMeterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Starts monitoring network speed with the provided [config].
  Future<void> startMonitoring(NetworkSpeedConfig config) {
    throw UnimplementedError('startMonitoring() has not been implemented.');
  }

  /// Stops monitoring.
  Future<void> stopMonitoring() {
    throw UnimplementedError('stopMonitoring() has not been implemented.');
  }

  /// Returns whether monitoring is active.
  Future<bool> get isMonitoring async {
    throw UnimplementedError('isMonitoring has not been implemented.');
  }

  /// Retrieves the latest snapshot, if available.
  Future<NetworkSpeedSnapshot?> get latestSnapshot async {
    throw UnimplementedError('latestSnapshot has not been implemented.');
  }

  /// Stream of continuous speed updates.
  Stream<NetworkSpeedSnapshot> get speedStream {
    throw UnimplementedError('speedStream has not been implemented.');
  }

  /// Throws a platform-specific exception.
  Never platformThrow(String message, {String? code}) {
    throw NetworkSpeedException(message, code: code);
  }
}

class _MethodChannelPlaceholder extends NetworkSpeedMeterPlatform {
  final Stream<NetworkSpeedSnapshot> _emptyStream =
      const Stream<NetworkSpeedSnapshot>.empty();

  @override
  Stream<NetworkSpeedSnapshot> get speedStream => _emptyStream;
}
