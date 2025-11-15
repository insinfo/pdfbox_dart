part of pdfbox.contentstream.pdf_stream_engine;

class SetFontOperator extends OperatorProcessor {
  SetFontOperator() : super(OperatorName.setFontAndSize);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final fontName = _expectOperand<COSName>(operands, 0);
    final fontSize = _expectOperand<COSNumber>(operands, 1).doubleValue;
    context.setFont(fontName, fontSize);
  }
}
