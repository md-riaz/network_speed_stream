import 'package:flutter_test/flutter_test.dart';
import 'package:network_speed_meter/network_speed_meter.dart';
import 'package:network_speed_meter/src/platform/method_channel_network_speed_meter.dart';
import 'package:network_speed_meter/src/platform/network_speed_meter_platform_interface.dart';

class _FakePlatform extends NetworkSpeedMeterPlatform {
  @override
  Future<bool> get isMonitoring async => false;

  @override
  Future<NetworkSpeedSnapshot?> get latestSnapshot async => null;

  @override
  Stream<NetworkSpeedSnapshot> get speedStream =>
      const Stream<NetworkSpeedSnapshot>.empty();

  @override
  Future<void> startMonitoring(NetworkSpeedConfig config) async {}

  @override
  Future<void> stopMonitoring() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default instance is MethodChannelNetworkSpeedMeter', () {
    expect(
      NetworkSpeedMeterPlatform.instance,
      isA<MethodChannelNetworkSpeedMeter>(),
    );
  });

  test('custom platform can be injected for testing', () {
    final fake = _FakePlatform();
    setNetworkSpeedMeterPlatform(fake);
    expect(NetworkSpeedMeterPlatform.instance, same(fake));
  });
}
