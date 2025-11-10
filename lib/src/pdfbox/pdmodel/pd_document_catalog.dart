import '../cos/cos_dictionary.dart';
import '../cos/cos_document.dart';
import '../cos/cos_name.dart';
import 'pd_page_tree.dart';

/// Represents the document catalog (/Root) dictionary.
class PDDocumentCatalog {
  PDDocumentCatalog(this._document, [COSDictionary? dictionary])
      : _dictionary = dictionary ?? _createDefaultCatalog();

  final COSDocument _document;
  final COSDictionary _dictionary;
  PDPageTree? _pageTree;

  COSDictionary get cosObject => _dictionary;

  PDPageTree get pages {
    _pageTree ??= _createPageTree();
    return _pageTree!;
  }

  PDPageTree _createPageTree() {
    final pagesDict = _dictionary.getCOSDictionary(COSName.pages);
    if (pagesDict == null) {
      throw StateError('Document catalog is missing /Pages dictionary');
    }
    return PDPageTree(_document, pagesDict);
  }

  static COSDictionary _createDefaultCatalog() {
    final dict = COSDictionary();
    dict.setName(COSName.type, 'Catalog');
    return dict;
  }
}
