import '../../../cos/cos_dictionary.dart';
import 'pd_standard_attribute_object.dart';

class PDTableAttributeObject extends PDStandardAttributeObject {
  static const String ownerTable = 'Table';

  static const String rowSpanKey = 'RowSpan';
  static const String colSpanKey = 'ColSpan';
  static const String headersKey = 'Headers';
  static const String scopeKey = 'Scope';
  static const String summaryKey = 'Summary';

  static const String scopeBoth = 'Both';
  static const String scopeColumn = 'Column';
  static const String scopeRow = 'Row';

  PDTableAttributeObject() : super() {
    setOwner(ownerTable);
  }

  PDTableAttributeObject.fromDictionary(COSDictionary dictionary)
      : super.fromDictionary(dictionary);

  int get rowSpan => getInteger(rowSpanKey, 1);

  set rowSpan(int value) => setInteger(rowSpanKey, value);

  int get colSpan => getInteger(colSpanKey, 1);

  set colSpan(int value) => setInteger(colSpanKey, value);

  List<String>? get headers => getArrayOfString(headersKey);

  set headers(List<String>? value) {
    if (value == null) {
      return;
    }
    setArrayOfString(headersKey, value);
  }

  String? get scope => getName(scopeKey);

  set scope(String? value) => setName(scopeKey, value);

  String? get summary => getString(summaryKey);

  set summary(String? value) => setString(summaryKey, value);

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (isSpecified(rowSpanKey)) {
      buffer.write(', RowSpan=$rowSpan');
    }
    if (isSpecified(colSpanKey)) {
      buffer.write(', ColSpan=$colSpan');
    }
    if (isSpecified(headersKey)) {
      buffer.write(', Headers=${_arrayToString(headers)}');
    }
    if (isSpecified(scopeKey)) {
      buffer.write(', Scope=$scope');
    }
    if (isSpecified(summaryKey)) {
      buffer.write(', Summary=$summary');
    }
    return buffer.toString();
  }

  String _arrayToString(List<String>? values) {
    if (values == null) {
      return 'null';
    }
    return '[${values.join(', ')}]';
  }
}

