import '../../cos/cos_base.dart';
import '../../cos/cos_dictionary.dart';
import '../interactive/action/pd_action_java_script.dart';
import 'pd_name_tree_node.dart';

/// JavaScript name tree wrapper producing [PDActionJavaScript] entries.
class PDJavascriptNameTreeNode
    extends PDNameTreeNode<PDActionJavaScript> {
  PDJavascriptNameTreeNode({COSDictionary? dictionary})
      : super(dictionary: dictionary);

  @override
  PDActionJavaScript? convertCOSToPD(COSBase? base) =>
      PDActionJavaScript.fromCOS(base);

  @override
  PDJavascriptNameTreeNode createChildNode(COSDictionary dictionary) =>
      PDJavascriptNameTreeNode(dictionary: dictionary);
}
