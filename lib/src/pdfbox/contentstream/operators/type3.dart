part of pdfbox.contentstream.pdf_stream_engine;

class Type3SetCharWidthOperator extends OperatorProcessor {
  Type3SetCharWidthOperator() : super(OperatorName.type3d0);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.length < 2) {
      return;
    }
    final wx = operands[0];
    final wy = operands[1];
    if (wx is! COSNumber || wy is! COSNumber) {
      return;
    }
    context.setType3GlyphWidth(wx.doubleValue, wy.doubleValue);
  }
}

class Type3SetCharWidthAndBoundingBoxOperator extends OperatorProcessor {
  Type3SetCharWidthAndBoundingBoxOperator()
      : super(OperatorName.type3d1);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.length < 6) {
      return;
    }
    final wx = operands[0];
    final wy = operands[1];
    final llx = operands[2];
    final lly = operands[3];
    final urx = operands[4];
    final ury = operands[5];
    if (wx is! COSNumber ||
        wy is! COSNumber ||
        llx is! COSNumber ||
        lly is! COSNumber ||
        urx is! COSNumber ||
        ury is! COSNumber) {
      return;
    }
    context.setType3GlyphWidthAndBoundingBox(
      wx.doubleValue,
      wy.doubleValue,
      llx.doubleValue,
      lly.doubleValue,
      urx.doubleValue,
      ury.doubleValue,
    );
  }
}
