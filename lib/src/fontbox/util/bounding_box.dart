class BoundingBox {
  double _lowerLeftX;
  double _lowerLeftY;
  double _upperRightX;
  double _upperRightY;

  BoundingBox({
    double lowerLeftX = 0,
    double lowerLeftY = 0,
    double upperRightX = 0,
    double upperRightY = 0,
  })  : _lowerLeftX = lowerLeftX,
        _lowerLeftY = lowerLeftY,
        _upperRightX = upperRightX,
        _upperRightY = upperRightY;

  BoundingBox.fromValues(double minX, double minY, double maxX, double maxY)
      : this(
          lowerLeftX: minX,
          lowerLeftY: minY,
          upperRightX: maxX,
          upperRightY: maxY,
        );

  factory BoundingBox.fromNumbers(Iterable<num> numbers) {
    final values = List<num>.from(numbers, growable: false);
    if (values.length != 4) {
      throw ArgumentError('BoundingBox requires four values');
    }
    return BoundingBox.fromValues(
      values[0].toDouble(),
      values[1].toDouble(),
      values[2].toDouble(),
      values[3].toDouble(),
    );
  }

  double get lowerLeftX => _lowerLeftX;
  set lowerLeftX(double value) => _lowerLeftX = value;

  double get lowerLeftY => _lowerLeftY;
  set lowerLeftY(double value) => _lowerLeftY = value;

  double get upperRightX => _upperRightX;
  set upperRightX(double value) => _upperRightX = value;

  double get upperRightY => _upperRightY;
  set upperRightY(double value) => _upperRightY = value;

  double get width => upperRightX - lowerLeftX;

  double get height => upperRightY - lowerLeftY;

  bool contains(double x, double y) {
    return x >= lowerLeftX && x <= upperRightX &&
        y >= lowerLeftY && y <= upperRightY;
  }

  @override
  String toString() {
    return '[${_format(lowerLeftX)},${_format(lowerLeftY)},'
        '${_format(upperRightX)},${_format(upperRightY)}]';
  }

  String _format(double value) {
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(1)
        : value.toString();
  }
}
