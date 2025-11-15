part of pdfbox.contentstream.pdf_stream_engine;

class SetLineWidthOperator extends OperatorProcessor {
  SetLineWidthOperator() : super(OperatorName.setLineWidth);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final width = _expectOperand<COSNumber>(operands, 0).doubleValue;
    context.setLineWidth(width);
  }
}

class SetLineCapOperator extends OperatorProcessor {
  SetLineCapOperator() : super(OperatorName.setLineCapstyle);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final style = _expectOperand<COSNumber>(operands, 0).intValue;
    context.setLineCap(style);
  }
}

class SetLineJoinOperator extends OperatorProcessor {
  SetLineJoinOperator() : super(OperatorName.setLineJoinstyle);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final style = _expectOperand<COSNumber>(operands, 0).intValue;
    context.setLineJoin(style);
  }
}

class SetMiterLimitOperator extends OperatorProcessor {
  SetMiterLimitOperator() : super(OperatorName.setLineMiterlimit);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final limit = _expectOperand<COSNumber>(operands, 0).doubleValue;
    context.setMiterLimit(limit);
  }
}

class SetLineDashOperator extends OperatorProcessor {
  SetLineDashOperator() : super(OperatorName.setLineDashpattern);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final dashArray = _expectOperand<COSArray>(operands, 0);
    final phase = _expectOperand<COSNumber>(operands, 1).doubleValue;
    context.setLineDashPattern(dashArray, phase);
  }
}

class SetRenderingIntentOperator extends OperatorProcessor {
  SetRenderingIntentOperator() : super(OperatorName.setRenderingintent);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final intent = _expectOperand<COSName>(operands, 0);
    context.setRenderingIntent(intent);
  }
}

class SetFlatnessOperator extends OperatorProcessor {
  SetFlatnessOperator() : super(OperatorName.setFlatness);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final flatness = _expectOperand<COSNumber>(operands, 0).doubleValue;
    context.setFlatnessTolerance(flatness);
  }
}

class SetSmoothnessOperator extends OperatorProcessor {
  SetSmoothnessOperator() : super(OperatorName.setSmoothness);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final smoothness = _expectOperand<COSNumber>(operands, 0).doubleValue;
    context.setSmoothnessTolerance(smoothness);
  }
}

class SetGraphicsStateOperator extends OperatorProcessor {
  SetGraphicsStateOperator() : super(OperatorName.setGraphicsStateParams);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final name = _expectOperand<COSName>(operands, 0);
    context.setGraphicsStateParameters(name);
  }
}
