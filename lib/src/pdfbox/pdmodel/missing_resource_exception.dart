import '../../io/exceptions.dart';

/// Thrown when a named resource referenced in the document is missing.
class MissingResourceException extends IOException {
  MissingResourceException(String message) : super(message);
}
