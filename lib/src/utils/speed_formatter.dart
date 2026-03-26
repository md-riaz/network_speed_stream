import '../enums/speed_unit.dart';

/// Utility to format byte-per-second speeds into human-friendly strings.
class SpeedFormatter {
  const SpeedFormatter();

  /// Formats the provided [bytesPerSecond] into a string using the closest unit.
  ///
  /// Defaults to automatic unit selection. When [unit] is provided, the value
  /// is forced into that unit.
  String format(
    int bytesPerSecond, {
    SpeedUnit? unit,
    int fractionDigits = 1,
  }) {
    final resolvedUnit = unit ?? _inferUnit(bytesPerSecond);
    final divisor = _divisorFor(resolvedUnit);
    final value = bytesPerSecond / divisor;
    final fixed = value.toStringAsFixed(
      resolvedUnit == SpeedUnit.bytesPerSecond ? 0 : fractionDigits,
    );
    return '$fixed ${_unitLabel(resolvedUnit)}';
  }

  SpeedUnit _inferUnit(int bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024 * 1024) {
      return SpeedUnit.gigabytesPerSecond;
    }
    if (bytesPerSecond >= 1024 * 1024) {
      return SpeedUnit.megabytesPerSecond;
    }
    if (bytesPerSecond >= 1024) {
      return SpeedUnit.kilobytesPerSecond;
    }
    return SpeedUnit.bytesPerSecond;
  }

  int _divisorFor(SpeedUnit unit) {
    switch (unit) {
      case SpeedUnit.bytesPerSecond:
        return 1;
      case SpeedUnit.kilobytesPerSecond:
        return 1024;
      case SpeedUnit.megabytesPerSecond:
        return 1024 * 1024;
      case SpeedUnit.gigabytesPerSecond:
        return 1024 * 1024 * 1024;
    }
  }

  String _unitLabel(SpeedUnit unit) {
    switch (unit) {
      case SpeedUnit.bytesPerSecond:
        return 'B/s';
      case SpeedUnit.kilobytesPerSecond:
        return 'KB/s';
      case SpeedUnit.megabytesPerSecond:
        return 'MB/s';
      case SpeedUnit.gigabytesPerSecond:
        return 'GB/s';
    }
  }
}
