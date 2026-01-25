import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/pd_dictionary_wrapper.dart';
import 'pd_default_attribute_object.dart';
import 'pd_structure_element.dart';
import 'pd_user_attribute_object.dart';
import '../taggedpdf/pd_list_attribute_object.dart';
import '../taggedpdf/pd_layout_attribute_object.dart';
import '../taggedpdf/pd_print_field_attribute_object.dart';
import '../taggedpdf/pd_table_attribute_object.dart';
import '../taggedpdf/pd_export_format_attribute_object.dart';

abstract class PDAttributeObject extends PDDictionaryWrapper {
  PDAttributeObject() : super();

  PDAttributeObject.fromDictionary(COSDictionary dictionary) : super(dictionary);

  static PDAttributeObject create(COSDictionary dictionary) {
    final owner = dictionary.getNameAsString(COSName.o);
    if (owner == PDUserAttributeObject.ownerUserProperties) {
      return PDUserAttributeObject.fromDictionary(dictionary);
    }
    if (owner == PDListAttributeObject.ownerList) {
      return PDListAttributeObject.fromDictionary(dictionary);
    }
    if (owner == PDLayoutAttributeObject.ownerLayout) {
      return PDLayoutAttributeObject.fromDictionary(dictionary);
    }
    if (owner == PDPrintFieldAttributeObject.ownerPrintField) {
      return PDPrintFieldAttributeObject.fromDictionary(dictionary);
    }
    if (owner == PDTableAttributeObject.ownerTable) {
      return PDTableAttributeObject.fromDictionary(dictionary);
    }
    if (owner == PDExportFormatAttributeObject.ownerXml100 ||
        owner == PDExportFormatAttributeObject.ownerHtml320 ||
        owner == PDExportFormatAttributeObject.ownerHtml401 ||
        owner == PDExportFormatAttributeObject.ownerOeb100 ||
        owner == PDExportFormatAttributeObject.ownerRtf105 ||
        owner == PDExportFormatAttributeObject.ownerCss100 ||
        owner == PDExportFormatAttributeObject.ownerCss200) {
      return PDExportFormatAttributeObject.fromDictionary(dictionary);
    }
    return PDDefaultAttributeObject.fromDictionary(dictionary);
  }

  PDStructureElement? _structureElement;

  PDStructureElement? get _currentStructureElement => _structureElement;

  void setStructureElement(PDStructureElement? structureElement) {
    _structureElement = structureElement;
  }

  String? getOwner() => cosObject.getNameAsString(COSName.o);

  void setOwner(String owner) {
    cosObject.setName(COSName.o, owner);
  }

  bool get isEmpty {
    if (getOwner() == null) {
      return cosObject.isEmpty;
    }
    var count = 0;
    for (final _ in cosObject.entries) {
      count++;
      if (count > 1) {
        return false;
      }
    }
    return count == 1;
  }

  void potentiallyNotifyChanged(COSBase? oldBase, COSBase? newBase) {
    if (_isValueChanged(oldBase, newBase)) {
      notifyChanged();
    }
  }

  bool _isValueChanged(COSBase? oldValue, COSBase? newValue) {
    if (oldValue == null) {
      return newValue != null;
    }
    return oldValue != newValue;
  }

  void notifyChanged() {
    _currentStructureElement?.attributeChanged(this);
  }

  @override
  String toString() => 'O=${getOwner()}';
}

