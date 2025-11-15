part of pdfbox.contentstream.pdf_stream_engine;

class BeginMarkedContentOperator extends OperatorProcessor {
  BeginMarkedContentOperator() : super(OperatorName.beginMarkedContent);

  @override
  void process(Operator operator, List<COSBase> operands) {
    COSName? tag;
    for (final operand in operands) {
      if (operand is COSName) {
        tag = operand;
        break;
      }
    }
    if (tag == null) {
      return;
    }
    context.beginMarkedContentSequence(tag, null);
  }
}

class BeginMarkedContentWithPropertiesOperator extends OperatorProcessor {
  BeginMarkedContentWithPropertiesOperator()
      : super(OperatorName.beginMarkedContentSeq);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.length < 2) {
      return;
    }
    final first = operands[0];
    if (first is! COSName) {
      return;
    }

    COSDictionary? properties;
    final second = operands[1];
    if (second is COSDictionary) {
      properties = second;
    } else if (second is COSName) {
      final prop = context.resources?.getPropertyList(second);
      properties = prop?.cosObject;
    }
    if (properties == null) {
      return;
    }
    context.beginMarkedContentSequence(first, properties);
  }
}

class EndMarkedContentOperator extends OperatorProcessor {
  EndMarkedContentOperator() : super(OperatorName.endMarkedContent);

  @override
  void process(Operator operator, List<COSBase> operands) {
    context.endMarkedContentSequence();
  }
}

class MarkedContentPointOperator extends OperatorProcessor {
  MarkedContentPointOperator() : super(OperatorName.markedContentPoint);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.isEmpty) {
      return;
    }
    final tag = operands[0];
    if (tag is! COSName) {
      return;
    }
    context.markedContentPoint(tag, null);
  }
}

class MarkedContentPointWithPropertiesOperator extends OperatorProcessor {
  MarkedContentPointWithPropertiesOperator()
      : super(OperatorName.markedContentPointWithProps);

  @override
  void process(Operator operator, List<COSBase> operands) {
    if (operands.length < 2) {
      return;
    }
    final tag = operands[0];
    if (tag is! COSName) {
      return;
    }
    final second = operands[1];
    COSDictionary? properties;
    if (second is COSDictionary) {
      properties = second;
    } else if (second is COSName) {
      properties =
          context.resources?.getPropertyList(second)?.cosObject;
    }
    if (properties == null) {
      return;
    }
    context.markedContentPoint(tag, properties);
  }
}
