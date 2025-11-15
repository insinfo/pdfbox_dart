part of pdfbox.contentstream.pdf_stream_engine;

class MoveToOperator extends OperatorProcessor {
  MoveToOperator() : super('m');

  @override
  void process(Operator operator, List<COSBase> operands) {
    final x = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final y = _expectOperand<COSNumber>(operands, 1).doubleValue;
    context.moveTo(x, y);
  }
}

class LineToOperator extends OperatorProcessor {
  LineToOperator() : super('l');

  @override
  void process(Operator operator, List<COSBase> operands) {
    final x = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final y = _expectOperand<COSNumber>(operands, 1).doubleValue;
    context.lineTo(x, y);
  }
}

class CurveToOperator extends OperatorProcessor {
  CurveToOperator() : super('c');

  @override
  void process(Operator operator, List<COSBase> operands) {
    final x1 = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final y1 = _expectOperand<COSNumber>(operands, 1).doubleValue;
    final x2 = _expectOperand<COSNumber>(operands, 2).doubleValue;
    final y2 = _expectOperand<COSNumber>(operands, 3).doubleValue;
    final x3 = _expectOperand<COSNumber>(operands, 4).doubleValue;
    final y3 = _expectOperand<COSNumber>(operands, 5).doubleValue;
    context.curveTo(x1, y1, x2, y2, x3, y3);
  }
}

class CurveToReplicateInitialPointOperator extends OperatorProcessor {
  CurveToReplicateInitialPointOperator() : super('v');

  @override
  void process(Operator operator, List<COSBase> operands) {
    final x2 = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final y2 = _expectOperand<COSNumber>(operands, 1).doubleValue;
    final x3 = _expectOperand<COSNumber>(operands, 2).doubleValue;
    final y3 = _expectOperand<COSNumber>(operands, 3).doubleValue;
    context.curveToReplicateInitialPoint(x2, y2, x3, y3);
  }
}

class CurveToReplicateFinalPointOperator extends OperatorProcessor {
  CurveToReplicateFinalPointOperator() : super('y');

  @override
  void process(Operator operator, List<COSBase> operands) {
    final x1 = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final y1 = _expectOperand<COSNumber>(operands, 1).doubleValue;
    final x3 = _expectOperand<COSNumber>(operands, 2).doubleValue;
    final y3 = _expectOperand<COSNumber>(operands, 3).doubleValue;
    context.curveToReplicateFinalPoint(x1, y1, x3, y3);
  }
}

class ClosePathOperator extends OperatorProcessor {
  ClosePathOperator() : super('h');

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.closePath();
  }
}

class RectangleOperator extends OperatorProcessor {
  RectangleOperator() : super('re');

  @override
  void process(Operator operator, List<COSBase> operands) {
    final x = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final y = _expectOperand<COSNumber>(operands, 1).doubleValue;
    final width = _expectOperand<COSNumber>(operands, 2).doubleValue;
    final height = _expectOperand<COSNumber>(operands, 3).doubleValue;
    context.appendRectangle(x, y, width, height);
  }
}
