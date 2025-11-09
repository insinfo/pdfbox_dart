import 'cos_number.dart';

class COSFloat extends COSNumber {
  COSFloat(num value) : value = value.toDouble();

  final double value;

  static COSFloat valueOf(num value) => COSFloat(value);

  @override
  double get doubleValue => value;

  @override
  int get intValue => value.toInt();

  @override
  String toString() => value.toString();
}
