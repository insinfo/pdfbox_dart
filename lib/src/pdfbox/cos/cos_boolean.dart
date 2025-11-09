import 'cos_base.dart';

class COSBoolean extends COSBase {
  COSBoolean._(this.value);

  static final COSBoolean trueValue = COSBoolean._(true);
  static final COSBoolean falseValue = COSBoolean._(false);

  final bool value;

  factory COSBoolean(bool value) => value ? trueValue : falseValue;

  static COSBoolean valueOf(bool value) => value ? trueValue : falseValue;

  @override
  String toString() => value ? 'true' : 'false';
}
