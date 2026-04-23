/// Typed exceptions thrown by the network and data layers.
/// All three extend [Exception] so callers can catch them specifically
/// or catch the base [Exception] type as a fallback.

/// Thrown when the PokéAPI returns a non-2xx HTTP status code.
class ServerException implements Exception {
  /// The HTTP status code returned by the server (e.g. 404, 500).
  final int statusCode;

  /// Human-readable description of the failure.
  final String message;

  /// Creates a [ServerException] with the given [statusCode] and [message].
  const ServerException({required this.statusCode, required this.message});

  @override
  String toString() => 'ServerException($statusCode): $message';
}

/// Thrown when the response body cannot be decoded as valid JSON
/// or the expected fields are missing or have the wrong type.
class ParseException implements Exception {
  /// Description of what failed to parse and why.
  final String message;

  /// Creates a [ParseException] with the given [message].
  const ParseException(this.message);

  @override
  String toString() => 'ParseException: $message';
}

/// Thrown when a network-level failure occurs (no internet,
/// DNS failure, connection refused, socket timeout).
class NetworkException implements Exception {
  /// Description of the underlying network error.
  final String message;

  /// Creates a [NetworkException] with the given [message].
  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
