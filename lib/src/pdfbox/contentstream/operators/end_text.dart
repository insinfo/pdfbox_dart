part of pdfbox.contentstream.pdf_stream_engine;

class EndTextOperator extends OperatorProcessor {
  EndTextOperator() : super(OperatorName.endText);

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.endText();
  }
}
