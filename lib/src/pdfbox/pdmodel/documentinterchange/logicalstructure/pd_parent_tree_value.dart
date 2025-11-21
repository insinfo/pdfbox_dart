import '../../../cos/cos_base.dart';

class PDParentTreeValue implements COSObjectable {
  final COSBase _base;

  PDParentTreeValue(this._base);

  @override
  COSBase get cosObject => _base;
}
