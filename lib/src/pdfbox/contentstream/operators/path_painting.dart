part of pdfbox.contentstream.pdf_stream_engine;

class StrokePathOperator extends OperatorProcessor {
  StrokePathOperator() : super('S');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.strokePath(close: false);
  }
}

class CloseStrokePathOperator extends OperatorProcessor {
  CloseStrokePathOperator() : super('s');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.strokePath(close: true);
  }
}

class FillPathOperator extends OperatorProcessor {
  FillPathOperator() : super('f');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.fillPath(PathWindingRule.nonZero, close: false);
  }
}

class FillAlternativeOperator extends OperatorProcessor {
  FillAlternativeOperator() : super('F');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.fillPath(PathWindingRule.nonZero, close: false);
  }
}

class FillEvenOddOperator extends OperatorProcessor {
  FillEvenOddOperator() : super('f*');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.fillPath(PathWindingRule.evenOdd, close: false);
  }
}

class FillAndStrokeOperator extends OperatorProcessor {
  FillAndStrokeOperator() : super('B');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.fillAndStrokePath(PathWindingRule.nonZero, close: false);
  }
}

class FillEvenOddAndStrokeOperator extends OperatorProcessor {
  FillEvenOddAndStrokeOperator() : super('B*');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.fillAndStrokePath(PathWindingRule.evenOdd, close: false);
  }
}

class CloseFillAndStrokeOperator extends OperatorProcessor {
  CloseFillAndStrokeOperator() : super('b');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.fillAndStrokePath(PathWindingRule.nonZero, close: true);
  }
}

class CloseFillEvenOddAndStrokeOperator extends OperatorProcessor {
  CloseFillEvenOddAndStrokeOperator() : super('b*');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.fillAndStrokePath(PathWindingRule.evenOdd, close: true);
  }
}

class EndPathOperator extends OperatorProcessor {
  EndPathOperator() : super('n');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.endPath();
  }
}
