import 'package:flutter_test/flutter_test.dart';
import 'package:network_speed_meter/src/utils/speed_formatter.dart';
import 'package:network_speed_meter/src/enums/speed_unit.dart';

void main() {
  const formatter = SpeedFormatter();

  test('formats using automatic units', () {
    expect(formatter.format(512), '512 B/s');
    expect(formatter.format(1024), '1.0 KB/s');
    expect(formatter.format(5 * 1024 * 1024), '5.0 MB/s');
  });

  test('formats using explicit unit', () {
    expect(
      formatter.format(2048, unit: SpeedUnit.kilobytesPerSecond),
      '2.0 KB/s',
    );
    expect(
      formatter.format(10 * 1024 * 1024, unit: SpeedUnit.megabytesPerSecond),
      '10.0 MB/s',
    );
  });
}
