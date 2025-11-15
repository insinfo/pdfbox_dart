part of pdfbox.contentstream.pdf_stream_engine;

class SetStrokingColorSpaceOperator extends OperatorProcessor {
  SetStrokingColorSpaceOperator() : super('CS');

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (!context.shouldProcessColorOperators) {
      return;
    }
    final colorSpaceObject = _expectOperand<COSBase>(operands, 0);
    final colorSpace = context.resolveColorSpace(colorSpaceObject);
    if (colorSpace != null) {
      context.setStrokingColorSpace(colorSpace);
    }
  }
}

class SetNonStrokingColorSpaceOperator extends OperatorProcessor {
  SetNonStrokingColorSpaceOperator() : super('cs');

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (!context.shouldProcessColorOperators) {
      return;
    }
    final colorSpaceObject = _expectOperand<COSBase>(operands, 0);
    final colorSpace = context.resolveColorSpace(colorSpaceObject);
    if (colorSpace != null) {
      context.setNonStrokingColorSpace(colorSpace);
    }
  }
}

class SetStrokingColorOperator extends OperatorProcessor {
  SetStrokingColorOperator() : super('SC');

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (!context.shouldProcessColorOperators) {
      return;
    }
    final values = _extractComponents(operands);
    context.setStrokingColor(values.components,
        patternName: values.patternName);
  }
}

class SetNonStrokingColorOperator extends OperatorProcessor {
  SetNonStrokingColorOperator() : super('sc');

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (!context.shouldProcessColorOperators) {
      return;
    }
    final values = _extractComponents(operands);
    context.setNonStrokingColor(values.components,
        patternName: values.patternName);
  }
}

class SetStrokingColorNOPatternOperator extends OperatorProcessor {
  SetStrokingColorNOPatternOperator() : super('SCN');

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (!context.shouldProcessColorOperators) {
      return;
    }
    final values = _extractComponents(operands);
    context.setStrokingColor(values.components,
        patternName: values.patternName);
  }
}

class SetNonStrokingColorNOPatternOperator extends OperatorProcessor {
  SetNonStrokingColorNOPatternOperator() : super('scn');

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (!context.shouldProcessColorOperators) {
      return;
    }
    final values = _extractComponents(operands);
    context.setNonStrokingColor(values.components,
        patternName: values.patternName);
  }
}

class SetStrokingGrayOperator extends OperatorProcessor {
  SetStrokingGrayOperator() : super('G');

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (!context.shouldProcessColorOperators) {
      return;
    }
    final gray = _expectOperand<COSNumber>(operands, 0).doubleValue;
    context.setStrokingGray(gray);
  }
}

class SetNonStrokingGrayOperator extends OperatorProcessor {
  SetNonStrokingGrayOperator() : super('g');

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (!context.shouldProcessColorOperators) {
      return;
    }
    final gray = _expectOperand<COSNumber>(operands, 0).doubleValue;
    context.setNonStrokingGray(gray);
  }
}

class SetStrokingRGBOperator extends OperatorProcessor {
  SetStrokingRGBOperator() : super('RG');

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (!context.shouldProcessColorOperators) {
      return;
    }
    final r = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final g = _expectOperand<COSNumber>(operands, 1).doubleValue;
    final b = _expectOperand<COSNumber>(operands, 2).doubleValue;
    context.setStrokingRGB(r, g, b);
  }
}

class SetNonStrokingRGBOperator extends OperatorProcessor {
  SetNonStrokingRGBOperator() : super('rg');

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (!context.shouldProcessColorOperators) {
      return;
    }
    final r = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final g = _expectOperand<COSNumber>(operands, 1).doubleValue;
    final b = _expectOperand<COSNumber>(operands, 2).doubleValue;
    context.setNonStrokingRGB(r, g, b);
  }
}

class SetStrokingCMYKOperator extends OperatorProcessor {
  SetStrokingCMYKOperator() : super('K');

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (!context.shouldProcessColorOperators) {
      return;
    }
    final c = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final m = _expectOperand<COSNumber>(operands, 1).doubleValue;
    final y = _expectOperand<COSNumber>(operands, 2).doubleValue;
    final k = _expectOperand<COSNumber>(operands, 3).doubleValue;
    context.setStrokingCMYK(c, m, y, k);
  }
}

class SetNonStrokingCMYKOperator extends OperatorProcessor {
  SetNonStrokingCMYKOperator() : super('k');

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (!context.shouldProcessColorOperators) {
      return;
    }
    final c = _expectOperand<COSNumber>(operands, 0).doubleValue;
    final m = _expectOperand<COSNumber>(operands, 1).doubleValue;
    final y = _expectOperand<COSNumber>(operands, 2).doubleValue;
    final k = _expectOperand<COSNumber>(operands, 3).doubleValue;
    context.setNonStrokingCMYK(c, m, y, k);
  }
}

class _ColorOperands {
  _ColorOperands(this.components, this.patternName);

  final List<double> components;
  final COSName? patternName;
}

_ColorOperands _extractComponents(List<COSBase> operands) {
  final components = <double>[];
  COSName? patternName;
  for (final operand in operands) {
    if (operand is COSNumber) {
      components.add(operand.doubleValue);
    } else if (operand is COSName) {
      patternName = operand;
    }
  }
  return _ColorOperands(components, patternName);
}
