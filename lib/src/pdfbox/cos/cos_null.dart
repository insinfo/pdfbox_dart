import 'cos_base.dart';

class COSNull extends COSBase {
  COSNull._();

  static final COSNull instance = COSNull._();
  static final COSNull NULL = instance;

  @override
  String toString() => 'null';
}
