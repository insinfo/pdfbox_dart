part of pdfbox.contentstream.pdf_stream_engine;

class SetCharSpacingOperator extends OperatorProcessor {
  SetCharSpacingOperator() : super(OperatorName.setCharSpacing);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.isEmpty) {
      return;
    }
    final value = operands.last;
    if (value is COSNumber) {
      context.setCharacterSpacing(value.doubleValue);
    }
  }
}

class SetWordSpacingOperator extends OperatorProcessor {
  SetWordSpacingOperator() : super(OperatorName.setWordSpacing);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.isEmpty) {
      return;
    }
    final value = operands[0];
    if (value is COSNumber) {
      context.setWordSpacing(value.doubleValue);
    }
  }
}

class SetTextHorizontalScalingOperator extends OperatorProcessor {
  SetTextHorizontalScalingOperator()
      : super(OperatorName.setTextHorizontalScaling);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final scale = operands.isEmpty ? null : operands[0];
    if (scale is COSNumber) {
      context.setHorizontalScaling(scale.doubleValue);
    }
  }
}

class SetTextLeadingOperator extends OperatorProcessor {
  SetTextLeadingOperator() : super(OperatorName.setTextLeading);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.isEmpty) {
      return;
    }
    final value = operands[0];
    if (value is COSNumber) {
      context.setTextLeading(value.doubleValue);
    }
  }
}

class SetTextRenderingModeOperator extends OperatorProcessor {
  SetTextRenderingModeOperator() : super(OperatorName.setTextRenderingmode);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.isEmpty) {
      return;
    }
    final value = operands[0];
    if (value is COSNumber) {
      context.setTextRenderingMode(value.intValue);
    }
  }
}

class SetTextRiseOperator extends OperatorProcessor {
  SetTextRiseOperator() : super(OperatorName.setTextRise);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.isEmpty) {
      return;
    }
    final value = operands[0];
    if (value is COSNumber) {
      context.setTextRise(value.doubleValue);
    }
  }
}
