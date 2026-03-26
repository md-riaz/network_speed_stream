import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/network_speed_config.dart';
import '../models/network_speed_exception.dart';
import '../models/network_speed_snapshot.dart';
import 'network_speed_meter_platform_interface.dart';

const _methodChannelName = 'network_speed_meter/methods';
const _eventChannelName = 'network_speed_meter/events';

/// Method-channel based implementation of [NetworkSpeedMeterPlatform].
class MethodChannelNetworkSpeedMeter extends NetworkSpeedMeterPlatform {
  MethodChannelNetworkSpeedMeter({BinaryMessenger? messenger})
      : _methodChannel =
            MethodChannel(_methodChannelName, const StandardMethodCodec(), messenger),
        _eventChannel =
            EventChannel(_eventChannelName, const StandardMethodCodec(), messenger);

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<NetworkSpeedSnapshot>? _stream;

  @override
  Future<void> startMonitoring(NetworkSpeedConfig config) async {
    config.validate();
    try {
      await _methodChannel.invokeMethod<void>('startMonitoring', config.toJson());
    } on PlatformException catch (e) {
      throw NetworkSpeedException(e.message ?? 'Failed to start monitoring',
          code: e.code);
    }
  }

  @override
  Future<void> stopMonitoring() async {
    try {
      await _methodChannel.invokeMethod<void>('stopMonitoring');
    } on PlatformException catch (e) {
      throw NetworkSpeedException(e.message ?? 'Failed to stop monitoring',
          code: e.code);
    }
  }

  @override
  Future<bool> get isMonitoring async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('isMonitoring') ?? false;
      return result;
    } on PlatformException catch (e) {
      throw NetworkSpeedException(e.message ?? 'Failed to query monitoring state',
          code: e.code);
    }
  }

  @override
  Future<NetworkSpeedSnapshot?> get latestSnapshot async {
    try {
      final map = await _methodChannel.invokeMapMethod<String, dynamic>(
        'latestSnapshot',
      );
      if (map == null) return null;
      return NetworkSpeedSnapshot.fromMap(map);
    } on PlatformException catch (e) {
      throw NetworkSpeedException(e.message ?? 'Failed to get snapshot',
          code: e.code);
    }
  }

  @override
  Stream<NetworkSpeedSnapshot> get speedStream {
    _stream ??= _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return NetworkSpeedSnapshot.fromMap(event);
      }
      throw NetworkSpeedException('Received malformed speed event');
    }).handleError((error, stackTrace) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('NetworkSpeedMeter stream error: $error');
      }
    }).asBroadcastStream();
    return _stream!;
  }
}

// Register the default instance when this library is loaded.
void _registerDefaultInstance() {
  NetworkSpeedMeterPlatform.instance = MethodChannelNetworkSpeedMeter();
}

final _defaultRegistration = _registerDefaultInstance();
