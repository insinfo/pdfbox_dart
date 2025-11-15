part of pdfbox.contentstream.pdf_stream_engine;

class InvokeXObjectOperator extends OperatorProcessor {
  InvokeXObjectOperator() : super(OperatorName.drawObject);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final cosName = _expectOperand<COSName>(operands, 0);
    context.processXObject(cosName);
  }
}
