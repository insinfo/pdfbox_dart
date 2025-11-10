/// Simple 2D vector used for font metrics and positioning.
class Vector {
  const Vector(this.x, this.y);

  /// X component.
  final double x;

  /// Y component.
  final double y;

  /// Creates a new vector scaled by [factor].
  Vector scale(double factor) => Vector(x * factor, y * factor);

  /// Returns a vector scaled independently along X/Y axes.
  Vector scaleXY(double sx, double sy) => Vector(x * sx, y * sy);

  @override
  String toString() => '($x, $y)';
}
