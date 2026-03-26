import 'package:flutter_test/flutter_test.dart';
import 'package:network_speed_meter/network_speed_meter.dart';

void main() {
  test('config validation passes for defaults', () {
    const config = NetworkSpeedConfig();
    expect(config.interval.inMilliseconds, 1000);
    expect(() => config.validate(), returnsNormally);
  });

  test('config validation rejects small interval', () {
    final config = NetworkSpeedConfig(interval: const Duration(milliseconds: 150));
    expect(() => config.validate(), throwsArgumentError);
  });

  test('config validation rejects empty notification title', () {
    final config = NetworkSpeedConfig(notificationTitle: '');
    expect(() => config.validate(), throwsArgumentError);
  });
}
