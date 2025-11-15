/// Signals that the supplied password did not unlock the document.
class InvalidPasswordException implements Exception {
  InvalidPasswordException(this.message);

  /// Additional context attached to the failure.
  final String message;

  @override
  String toString() => 'InvalidPasswordException: $message';
}
