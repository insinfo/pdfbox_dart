import '../cos/cos_base.dart' show COSObjectable;
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import 'common/pd_destination_name_tree_node.dart';
import 'common/pd_embedded_files_name_tree_node.dart';
import 'common/pd_javascript_name_tree_node.dart';

/// Wraps the document level `/Names` dictionary, exposing common name trees.
///
/// The concrete PD wrappers (destinations, embedded files, JavaScript actions)
/// are still TODO, so for now these accessors return nodes whose values are
/// raw [COSDictionary] instances.
class PDDocumentNameDictionary implements COSObjectable {
  PDDocumentNameDictionary(this._catalogDictionary, [COSDictionary? dictionary])
      : _dictionary =
            dictionary ?? _ensureNamesDictionary(_catalogDictionary);

  final COSDictionary _catalogDictionary;
  final COSDictionary _dictionary;
  PDDestinationNameTreeNode? _destsNode;
  PDEmbeddedFilesNameTreeNode? _embeddedFilesNode;
  PDJavascriptNameTreeNode? _javascriptNode;

  @override
  COSDictionary get cosObject => _dictionary;

  /// Returns the `/Dests` name tree stored in either the names dictionary or
  /// directly in the catalog (as some PDFs do).
  PDDestinationNameTreeNode? get dests {
    final namesDict = _dictionary.getCOSDictionary(COSName.dests);
    final candidate = namesDict ?? _catalogDictionary.getCOSDictionary(COSName.dests);
    if (candidate == null) {
      _destsNode = null;
      return null;
    }
    final cached = _destsNode;
    if (cached != null && identical(cached.cosObject, candidate)) {
      return cached;
    }
    final node = PDDestinationNameTreeNode(dictionary: candidate);
    _destsNode = node;
    return node;
  }

  /// Associates a new `/Dests` tree. Passing `null` removes the entry from the
  /// names dictionary and clears any legacy catalog-level `/Dests` entry.
  set dests(PDDestinationNameTreeNode? value) {
    _destsNode = value;
    if (value == null) {
      _dictionary.removeItem(COSName.dests);
      _catalogDictionary.setItem(COSName.dests, null);
      return;
    }
    _dictionary[COSName.dests] = value.cosObject;
    _catalogDictionary.setItem(COSName.dests, null);
  }

  PDEmbeddedFilesNameTreeNode? get embeddedFiles {
    final dict = _dictionary.getCOSDictionary(COSName.embeddedFiles);
    if (dict == null) {
      _embeddedFilesNode = null;
      return null;
    }
    final cached = _embeddedFilesNode;
    if (cached != null && identical(cached.cosObject, dict)) {
      return cached;
    }
    final node = PDEmbeddedFilesNameTreeNode(dictionary: dict);
    _embeddedFilesNode = node;
    return node;
  }

  set embeddedFiles(PDEmbeddedFilesNameTreeNode? value) {
    _embeddedFilesNode = value;
    if (value == null) {
      _dictionary.removeItem(COSName.embeddedFiles);
    } else {
      _dictionary[COSName.embeddedFiles] = value.cosObject;
    }
  }

  PDJavascriptNameTreeNode? get javascript {
    final dict = _dictionary.getCOSDictionary(COSName.javaScript);
    if (dict == null) {
      _javascriptNode = null;
      return null;
    }
    final cached = _javascriptNode;
    if (cached != null && identical(cached.cosObject, dict)) {
      return cached;
    }
    final node = PDJavascriptNameTreeNode(dictionary: dict);
    _javascriptNode = node;
    return node;
  }

  set javascript(PDJavascriptNameTreeNode? value) {
    _javascriptNode = value;
    if (value == null) {
      _dictionary.removeItem(COSName.javaScript);
    } else {
      _dictionary[COSName.javaScript] = value.cosObject;
    }
  }

  static COSDictionary _ensureNamesDictionary(COSDictionary catalog) {
    final existing = catalog.getCOSDictionary(COSName.names);
    if (existing != null) {
      return existing;
    }
    final created = COSDictionary();
    catalog[COSName.names] = created;
    return created;
  }
}
