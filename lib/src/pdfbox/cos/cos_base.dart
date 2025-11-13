import 'cos_object_key.dart';

abstract class COSVisitor {
  void visit(COSBase object);
}

abstract class COSObjectable {
  COSBase get cosObject;
}


abstract class COSBase implements COSObjectable {
  bool _isDirect = false;
  COSObjectKey? _key;

  @override
  COSBase get cosObject => this;

  bool get isDirect => _isDirect;

  set isDirect(bool value) => _isDirect = value;

  COSObjectKey? get key => _key;

  set key(COSObjectKey? value) => _key = value;

  void accept(COSVisitor visitor) => visitor.visit(this);
}
