import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_structure_node.dart';

class PDStructureElement extends PDStructureNode {
  static const String TYPE = 'StructElem';

  PDStructureElement(COSDictionary dictionary) : super.fromDictionary(dictionary);

  PDStructureElement.create(String structureType, PDStructureNode parent) : super(TYPE) {
    setStructureType(structureType);
    setParent(parent);
  }

  String? getStructureType() {
    return cosObject.getNameAsString(COSName.s);
  }

  void setStructureType(String structureType) {
    cosObject.setName(COSName.s, structureType);
  }

  PDStructureNode? getParent() {
    final parent = cosObject.getDictionaryObject(COSName.p);
    if (parent is COSDictionary) {
      return PDStructureNode.create(parent);
    }
    return null;
  }

  void setParent(PDStructureNode? structureNode) {
    cosObject[COSName.p] = structureNode;
  }
}
