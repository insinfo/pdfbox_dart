part of pdfbox.contentstream.pdf_stream_engine;

class BeginTextOperator extends OperatorProcessor {
  BeginTextOperator() : super(OperatorName.beginText);

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.beginText();
  }
}
