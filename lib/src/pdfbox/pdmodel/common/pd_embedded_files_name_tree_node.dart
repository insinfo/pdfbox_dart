import '../../cos/cos_base.dart';
import '../../cos/cos_dictionary.dart';
import 'pd_file_specification.dart';
import 'pd_name_tree_node.dart';

/// Embedded files name tree wrapper backed by file specifications.
class PDEmbeddedFilesNameTreeNode
    extends PDNameTreeNode<PDFileSpecification> {
  PDEmbeddedFilesNameTreeNode({COSDictionary? dictionary})
      : super(dictionary: dictionary);

  @override
  PDFileSpecification? convertCOSToPD(COSBase? base) =>
      PDFileSpecification.fromCOS(base);

  @override
  PDEmbeddedFilesNameTreeNode createChildNode(COSDictionary dictionary) =>
      PDEmbeddedFilesNameTreeNode(dictionary: dictionary);
}
