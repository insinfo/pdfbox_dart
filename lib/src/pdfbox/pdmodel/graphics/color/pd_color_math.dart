/// Utility helpers for colour space implementations.
class PDColorMath {
  const PDColorMath._();

  /// Clamps [value] to the 0.0 to 1.0 range used by PDF colour components.
  static double clampUnit(double value) {
    if (value <= 0.0) {
      return 0.0;
    }
    if (value >= 1.0) {
      return 1.0;
    }
    return value;
  }
}
