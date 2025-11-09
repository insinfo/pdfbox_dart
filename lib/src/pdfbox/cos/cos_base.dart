abstract class COSVisitor {
  void visit(COSBase object);
}

abstract class COSObjectable {
  COSBase get cosObject;
}

abstract class COSBase implements COSObjectable {
  bool isDirect = false;

  @override
  COSBase get cosObject => this;

  void accept(COSVisitor visitor) => visitor.visit(this);
}
