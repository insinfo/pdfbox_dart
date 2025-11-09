import 'cos_number.dart';

class COSInteger extends COSNumber {
  COSInteger._(this.value);

  static final Map<int, COSInteger> _cache = <int, COSInteger>{};

  final int value;

  factory COSInteger(int value) =>
      _cache.putIfAbsent(value, () => COSInteger._(value));

  static COSInteger valueOf(int value) => COSInteger(value);

  @override
  double get doubleValue => value.toDouble();

  @override
  int get intValue => value;

  @override
  String toString() => value.toString();
}
