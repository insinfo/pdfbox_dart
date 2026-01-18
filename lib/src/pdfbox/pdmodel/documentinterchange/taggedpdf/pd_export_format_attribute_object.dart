import '../../../cos/cos_dictionary.dart';
import 'pd_layout_attribute_object.dart';
import 'pd_list_attribute_object.dart';
import 'pd_table_attribute_object.dart';

class PDExportFormatAttributeObject extends PDLayoutAttributeObject {
  static const String ownerXml100 = 'XML-1.00';
  static const String ownerHtml320 = 'HTML-3.2';
  static const String ownerHtml401 = 'HTML-4.01';
  static const String ownerOeb100 = 'OEB-1.00';
  static const String ownerRtf105 = 'RTF-1.05';
  static const String ownerCss100 = 'CSS-1.00';
  static const String ownerCss200 = 'CSS-2.00';

  PDExportFormatAttributeObject(String owner) : super() {
    setOwner(owner);
  }

  PDExportFormatAttributeObject.fromDictionary(COSDictionary dictionary)
      : super.fromDictionary(dictionary);

  String get listNumbering =>
      getName(PDListAttributeObject.listNumberingKey,
          PDListAttributeObject.listNumberingNone) ??
      PDListAttributeObject.listNumberingNone;

  set listNumbering(String value) =>
      setName(PDListAttributeObject.listNumberingKey, value);

  int get rowSpan => getInteger(PDTableAttributeObject.rowSpanKey, 1);

  set rowSpan(int value) => setInteger(PDTableAttributeObject.rowSpanKey, value);

  int get colSpan => getInteger(PDTableAttributeObject.colSpanKey, 1);

  set colSpan(int value) => setInteger(PDTableAttributeObject.colSpanKey, value);

  List<String>? get headers =>
      getArrayOfString(PDTableAttributeObject.headersKey);

  set headers(List<String>? value) {
    if (value == null) {
      return;
    }
    setArrayOfString(PDTableAttributeObject.headersKey, value);
  }

  String? get scope => getName(PDTableAttributeObject.scopeKey);

  set scope(String? value) => setName(PDTableAttributeObject.scopeKey, value);

  String? get summary => getString(PDTableAttributeObject.summaryKey);

  set summary(String? value) =>
      setString(PDTableAttributeObject.summaryKey, value);

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (isSpecified(PDListAttributeObject.listNumberingKey)) {
      buffer.write(', ListNumbering=$listNumbering');
    }
    if (isSpecified(PDTableAttributeObject.rowSpanKey)) {
      buffer.write(', RowSpan=$rowSpan');
    }
    if (isSpecified(PDTableAttributeObject.colSpanKey)) {
      buffer.write(', ColSpan=$colSpan');
    }
    if (isSpecified(PDTableAttributeObject.headersKey)) {
      buffer.write(', Headers=${_arrayToString(headers)}');
    }
    if (isSpecified(PDTableAttributeObject.scopeKey)) {
      buffer.write(', Scope=$scope');
    }
    if (isSpecified(PDTableAttributeObject.summaryKey)) {
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
