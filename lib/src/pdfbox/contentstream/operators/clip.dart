part of pdfbox.contentstream.pdf_stream_engine;

class ClipPathOperator extends OperatorProcessor {
  ClipPathOperator() : super('W');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.clipPath(PathWindingRule.nonZero);
  }
}

class ClipEvenOddOperator extends OperatorProcessor {
  ClipEvenOddOperator() : super('W*');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.clipPath(PathWindingRule.evenOdd);
  }
}
