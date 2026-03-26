/// Custom exception for network speed monitoring failures.
class NetworkSpeedException implements Exception {
  /// Creates an exception with a [message] and optional [code].
  NetworkSpeedException(this.message, {this.code});

  /// Error code, if provided by the platform.
  final String? code;

  /// Human-readable description of the error.
  final String message;

  @override
  String toString() => 'NetworkSpeedException($code): $message';
}
