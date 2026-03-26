library network_speed_meter;

import 'package:flutter/foundation.dart';

import 'src/models/network_speed_config.dart';
import 'src/models/network_speed_exception.dart';
import 'src/models/network_speed_snapshot.dart';
import 'src/platform/method_channel_network_speed_meter.dart';
import 'src/platform/network_speed_meter_platform_interface.dart';
import 'src/utils/speed_formatter.dart';
import 'src/enums/speed_unit.dart';

export 'src/models/network_speed_config.dart';
export 'src/models/network_speed_exception.dart';
export 'src/models/network_speed_snapshot.dart';
export 'src/utils/speed_formatter.dart';
export 'src/enums/speed_unit.dart';

/// Public API for the network speed meter plugin.
class NetworkSpeedMeter {
  NetworkSpeedMeter._internal(this._platform) {
    NetworkSpeedMeterPlatform.instance = _platform;
  }

  /// Singleton instance.
  static final NetworkSpeedMeter instance =
      NetworkSpeedMeter._internal(MethodChannelNetworkSpeedMeter());

  final NetworkSpeedMeterPlatform _platform;

  /// Indicates whether monitoring is active.
  Future<bool> get isMonitoring => _platform.isMonitoring;

  /// Starts monitoring network speed.
  Future<void> startMonitoring({NetworkSpeedConfig config = const NetworkSpeedConfig()}) {
    return _platform.startMonitoring(config);
  }

  /// Stops monitoring.
  Future<void> stopMonitoring() => _platform.stopMonitoring();

  /// Stream of speed snapshots.
  Stream<NetworkSpeedSnapshot> get speedStream => _platform.speedStream;

  /// Last known snapshot, if available.
  Future<NetworkSpeedSnapshot?> get latestSnapshot => _platform.latestSnapshot;
}

/// A convenience accessor.
NetworkSpeedMeter get networkSpeedMeter => NetworkSpeedMeter.instance;

/// Exposes a formatting utility for convenience.
const speedFormatter = SpeedFormatter();

/// Allows injection of a custom platform implementation for testing.
@visibleForTesting
void setNetworkSpeedMeterPlatform(NetworkSpeedMeterPlatform platform) {
  NetworkSpeedMeterPlatform.instance = platform;
}
