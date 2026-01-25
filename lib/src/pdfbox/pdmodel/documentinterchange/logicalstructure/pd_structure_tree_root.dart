import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_base.dart';
import '../../common/pd_number_tree_node.dart';
import '../../pd_structure_element_name_tree_node.dart';
import 'pd_structure_node.dart';
import 'pd_parent_tree_value.dart';

class PDStructureTreeRoot extends PDStructureNode {
  static const String TYPE = 'StructTreeRoot';

  PDStructureTreeRoot([COSDictionary? dictionary]) 
      : super.fromDictionary(dictionary ?? COSDictionary()) {
    if (dictionary == null) {
      cosObject[COSName.type] = COSName(TYPE);
    }
  }

  PDNumberTreeNode<PDParentTreeValue>? getParentTree() {
    final parentTree = cosObject.getDictionaryObject(COSName.parentTree);
    if (parentTree is COSDictionary) {
      return PDNumberTreeNode<PDParentTreeValue>(
        dictionary: parentTree,
        valueFactory: (base) => PDParentTreeValue(base),
      );
    }
    return null;
  }

  void setParentTree(PDNumberTreeNode<PDParentTreeValue>? parentTree) {
    cosObject[COSName.parentTree] = parentTree;
  }

  int getParentTreeNextKey() {
    return cosObject.getInt(COSName.parentTreeNextKey) ?? 0;
  }

  void setParentTreeNextKey(int parentTreeNextKey) {
    cosObject.setInt(COSName.parentTreeNextKey, parentTreeNextKey);
  }

  COSBase? get k => cosObject.getDictionaryObject(COSName.k);

  set k(COSBase? value) {
    cosObject[COSName.k] = value;
  }

  PDStructureElementNameTreeNode? getIDTree() {
    final idTree = cosObject.getDictionaryObject(COSName.idTree);
    if (idTree is COSDictionary) {
      return PDStructureElementNameTreeNode(idTree);
    }
    return null;
  }

  void setIDTree(PDStructureElementNameTreeNode? idTree) {
    cosObject[COSName.idTree] = idTree;
  }
}

