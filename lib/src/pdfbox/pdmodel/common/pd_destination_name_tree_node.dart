import '../../cos/cos_base.dart';
import '../../cos/cos_dictionary.dart';
import 'pd_destination.dart';
import 'pd_name_tree_node.dart';

/// Destination name tree wrapper that materializes typed [PDDestination]
/// instances, including page destinations (`PDPageDestination`).
class PDDestinationNameTreeNode extends PDNameTreeNode<PDDestination> {
  PDDestinationNameTreeNode({COSDictionary? dictionary})
      : super(dictionary: dictionary);

  @override
  PDDestination? convertCOSToPD(COSBase? base) => PDDestination.fromCOS(base);

  @override
  PDDestinationNameTreeNode createChildNode(COSDictionary dictionary) =>
      PDDestinationNameTreeNode(dictionary: dictionary);
}
