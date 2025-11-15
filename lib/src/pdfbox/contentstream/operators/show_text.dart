part of pdfbox.contentstream.pdf_stream_engine;

class ShowTextOperator extends OperatorProcessor {
  ShowTextOperator() : super(OperatorName.showText);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final text = _expectOperand<COSString>(operands, 0);
    context.showTextString(text);
  }
}

class ShowTextArrayOperator extends OperatorProcessor {
  ShowTextArrayOperator() : super(OperatorName.showTextAdjusted);

  @override
  void process(Operator operator, List<COSBase> operands) {
    final array = _expectOperand<COSArray>(operands, 0);
    context.showTextStrings(array);
  }
}

class ShowTextLineOperator extends OperatorProcessor {
  ShowTextLineOperator() : super(OperatorName.showTextLine);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.isEmpty) {
      return;
    }
    final value = operands[0];
    if (value is COSString) {
      context.showTextLine(value);
    }
  }
}

class ShowTextLineAndSpaceOperator extends OperatorProcessor {
  ShowTextLineAndSpaceOperator()
      : super(OperatorName.showTextLineAndSpace);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.length < 3) {
      return;
    }
    final first = operands[0];
    final second = operands[1];
    final third = operands[2];
    if (first is COSNumber && second is COSNumber && third is COSString) {
      context.showTextLineAndSpacing(
        first.doubleValue,
        second.doubleValue,
        third,
      );
    }
  }
}
