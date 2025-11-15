part of pdfbox.contentstream.pdf_stream_engine;

class SaveGraphicsStateOperator extends OperatorProcessor {
  SaveGraphicsStateOperator() : super('q');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.pushGraphicsState();
  }
}

class RestoreGraphicsStateOperator extends OperatorProcessor {
  RestoreGraphicsStateOperator() : super('Q');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.popGraphicsState();
  }
}
