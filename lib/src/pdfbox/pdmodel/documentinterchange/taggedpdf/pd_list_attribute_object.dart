import '../../../cos/cos_dictionary.dart';
import 'pd_standard_attribute_object.dart';

class PDListAttributeObject extends PDStandardAttributeObject {
  static const String ownerList = 'List';

  static const String listNumberingKey = 'ListNumbering';

  static const String listNumberingCircle = 'Circle';
  static const String listNumberingDecimal = 'Decimal';
  static const String listNumberingDisc = 'Disc';
  static const String listNumberingLowerAlpha = 'LowerAlpha';
  static const String listNumberingLowerRoman = 'LowerRoman';
  static const String listNumberingNone = 'None';
  static const String listNumberingSquare = 'Square';
  static const String listNumberingUpperAlpha = 'UpperAlpha';
  static const String listNumberingUpperRoman = 'UpperRoman';

  PDListAttributeObject() : super() {
    setOwner(ownerList);
  }

  PDListAttributeObject.fromDictionary(COSDictionary dictionary)
      : super.fromDictionary(dictionary);

  String get listNumbering =>
      getName(listNumberingKey, listNumberingNone) ?? listNumberingNone;

  set listNumbering(String value) => setName(listNumberingKey, value);

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (isSpecified(listNumberingKey)) {
      buffer.write(', ListNumbering=$listNumbering');
    }
    return buffer.toString();
  }
}

