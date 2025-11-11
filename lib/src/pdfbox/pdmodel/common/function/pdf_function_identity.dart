import 'pdf_function.dart';

class PDFunctionIdentity extends PDFunction {
  PDFunctionIdentity() : super(null);

  @override
  int get functionType =>
      throw UnsupportedError('Identity function has no type');

  @override
  List<double> eval(List<double> input) =>
      List<double>.from(input, growable: false);

  @override
  List<double> clipToRange(List<double> values) => values;
}
