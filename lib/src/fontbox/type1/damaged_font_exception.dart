import '../../io/exceptions.dart';

/// Raised when a Type 1 font program is structurally invalid.
class DamagedFontException extends IOException {
  DamagedFontException(String message) : super(message);
}
