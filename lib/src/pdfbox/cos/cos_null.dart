import 'cos_base.dart';

class COSNull extends COSBase {
  COSNull._();

  static final COSNull instance = COSNull._();

  @override
  String toString() => 'null';
}
