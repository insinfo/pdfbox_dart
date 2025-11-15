part of pdfbox.contentstream.pdf_stream_engine;

class ShadingFillOperator extends OperatorProcessor {
  ShadingFillOperator() : super(OperatorName.shadingFill);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.isEmpty) {
      return;
    }
    final name = operands[0];
    if (name is! COSName) {
      return;
    }
    context.shadingFill(name);
  }
}
