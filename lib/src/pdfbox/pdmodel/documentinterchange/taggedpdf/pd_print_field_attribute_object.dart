import '../../../cos/cos_dictionary.dart';
import 'pd_standard_attribute_object.dart';

class PDPrintFieldAttributeObject extends PDStandardAttributeObject {
  static const String ownerPrintField = 'PrintField';

  static const String _role = 'Role';
  static const String _checked = 'checked';
  static const String _desc = 'Desc';

  static const String roleRb = 'rb';
  static const String roleCb = 'cb';
  static const String rolePb = 'pb';
  static const String roleTv = 'tv';

  static const String checkedStateOn = 'on';
  static const String checkedStateOff = 'off';
  static const String checkedStateNeutral = 'neutral';

  PDPrintFieldAttributeObject() : super() {
    setOwner(ownerPrintField);
  }

  PDPrintFieldAttributeObject.fromDictionary(COSDictionary dictionary)
      : super.fromDictionary(dictionary);

  String? get role => getName(_role);

  set role(String? value) => setName(_role, value);

  String get checkedState =>
      getName(_checked, checkedStateOff) ?? checkedStateOff;

  set checkedState(String value) => setName(_checked, value);

  String? get alternateName => getString(_desc);

  set alternateName(String? value) => setString(_desc, value);

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (isSpecified(_role)) {
      buffer.write(', Role=$role');
    }
    if (isSpecified(_checked)) {
      buffer.write(', Checked=$checkedState');
    }
    if (isSpecified(_desc)) {
      buffer.write(', Desc=$alternateName');
    }
    return buffer.toString();
  }
}
