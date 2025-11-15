part of pdfbox.contentstream.pdf_stream_engine;

class SetTextMatrixOperator extends OperatorProcessor {
  SetTextMatrixOperator() : super(OperatorName.setMatrix);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final a = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final b = _expectOperand<COSNumber>(operands, 1).doubleValue;
    final c = _expectOperand<COSNumber>(operands, 2).doubleValue;
    final d = _expectOperand<COSNumber>(operands, 3).doubleValue;
    final e = _expectOperand<COSNumber>(operands, 4).doubleValue;
    final f = _expectOperand<COSNumber>(operands, 5).doubleValue;
    context.setTextMatrix(a, b, c, d, e, f);
  }
}

class ConcatMatrixOperator extends OperatorProcessor {
  ConcatMatrixOperator() : super(OperatorName.concat);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final a = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final b = _expectOperand<COSNumber>(operands, 1).doubleValue;
    final c = _expectOperand<COSNumber>(operands, 2).doubleValue;
    final d = _expectOperand<COSNumber>(operands, 3).doubleValue;
    final e = _expectOperand<COSNumber>(operands, 4).doubleValue;
    final f = _expectOperand<COSNumber>(operands, 5).doubleValue;
    context.concatenateMatrix(a, b, c, d, e, f);
  }
}
