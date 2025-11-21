import 'common/pd_name_tree_node.dart';
import 'documentinterchange/logicalstructure/pd_structure_element.dart';
import '../cos/cos_base.dart';
import '../cos/cos_dictionary.dart';

class PDStructureElementNameTreeNode extends PDNameTreeNode<PDStructureElement> {
  PDStructureElementNameTreeNode([COSDictionary? dictionary]) : super(dictionary: dictionary);

  @override
  PDStructureElement? convertCOSToPD(COSBase? base) {
    if (base is COSDictionary) {
      return PDStructureElement(base);
    }
    return null;
  }

  @override
  PDNameTreeNode<PDStructureElement> createChildNode(COSDictionary dictionary) {
    return PDStructureElementNameTreeNode(dictionary);
  }
}
