part of pdfbox.contentstream.pdf_stream_engine;

class MoveTextOperator extends OperatorProcessor {
  MoveTextOperator() : super(OperatorName.moveText);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final tx = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final ty = _expectOperand<COSNumber>(operands, 1).doubleValue;
    context.moveText(tx, ty);
  }
}

class MoveTextSetLeadingOperator extends OperatorProcessor {
  MoveTextSetLeadingOperator() : super(OperatorName.moveTextSetLeading);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final txNumber = _expectOperand<COSNumber>(operands, 0);
    final tyNumber = _expectOperand<COSNumber>(operands, 1);
    final tx = txNumber.doubleValue;
    final ty = tyNumber.doubleValue;
    context.setTextLeading(-ty);
    context.moveText(tx, ty);
  }
}

class NextLineOperator extends OperatorProcessor {
  NextLineOperator() : super(OperatorName.nextLine);

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.nextLine();
  }
}
