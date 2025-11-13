import 'dart:typed_data';

import '../../cos/cos_dictionary.dart';
import 'operator_name.dart';

/// Representation of an operator in a PDF content stream.
class Operator {
  Operator._(this._operator);

  final String _operator;
  Uint8List? _imageData;
  COSDictionary? _imageParameters;

  static final Map<String, Operator> _operators = <String, Operator>{};

  static Operator getOperator(String operator) {
    if (operator == OperatorName.beginInlineImageData ||
        operator == OperatorName.beginInlineImage) {
      return Operator._(operator);
    }
    return _operators.putIfAbsent(operator, () => Operator._(operator));
  }

  String get name => _operator;

  Uint8List? get imageData => _imageData;

  void setImageData(Uint8List? data) {
    _imageData = data;
  }

  COSDictionary? get imageParameters => _imageParameters;

  void setImageParameters(COSDictionary? parameters) {
    _imageParameters = parameters;
  }

  @override
  String toString() => 'PDFOperator{$_operator}';
}
