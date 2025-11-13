import 'dart:collection';

import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_document.dart';
import '../cos/cos_name.dart';
import '../cos/cos_null.dart';
import '../cos/cos_object.dart';
import 'pd_page.dart';
import 'resource_cache.dart';

/// Represents the page tree rooted at a /Pages dictionary.
class PDPageTree extends IterableBase<PDPage> {
  PDPageTree(this._document, this._root, [this._resourceCache]);

  final COSDocument _document;
  final COSDictionary _root;
  final ResourceCache? _resourceCache;
  List<PDPage>? _cachedPages;

  COSDictionary get cosObject => _root;

  /// Number of leaf pages reachable from this tree.
  int get count {
    final explicit = _root.getInt(COSName.count);
    if (explicit != null) {
      return explicit;
    }
    return _pages.length;
  }

  /// Returns the page at [index].
  PDPage operator [](int index) {
    final pages = _pages;
    if (index < 0 || index >= pages.length) {
      throw RangeError.range(index, 0, pages.length - 1, 'index');
    }
    return pages[index];
  }

  /// Appends [page] to the end of this page tree.
  void addPage(PDPage page) {
    final pages = _pages;
    final parent = pages.isEmpty ? _root : (pages.last.parent ?? _root);
    final kids = _ensureKidsArray(parent);
    kids.add(_ensureIndirect(page.cosObject));
    page.resourceCache ??= _resourceCache;
    page.parent = parent;
    _invalidateCache();
    _updateCounts(parent);
  }

  /// Inserts [page] at the given [index].
  void insertPage(int index, PDPage page) {
    final pages = _pages;
    if (index < 0 || index > pages.length) {
      throw RangeError.range(index, 0, pages.length, 'index');
    }
    if (index == pages.length) {
      addPage(page);
      return;
    }

    final referencePage = pages[index];
    final parent = referencePage.parent ?? _root;
    final kids = _ensureKidsArray(parent);
    final referenceIndex = _indexOfChild(kids, referencePage.cosObject);
    final insertionIndex = referenceIndex < 0 ? kids.length : referenceIndex;
    kids.insert(insertionIndex, _ensureIndirect(page.cosObject));
    page.resourceCache ??= _resourceCache;
    page.parent = parent;
    _invalidateCache();
    _updateCounts(parent);
  }

  /// Removes [page] from the tree if present.
  bool removePage(PDPage page) {
    final removed = _removePage(_root, page.cosObject);
    if (removed) {
      page.parent = null;
      _invalidateCache();
      _updateCounts(_root);
    }
    return removed;
  }

  /// Removes and returns the page at [index].
  PDPage removePageAt(int index) {
    final page = this[index];
    if (!removePage(page)) {
      throw StateError('Unable to remove page at index $index');
    }
    return page;
  }

  /// Returns the index of [page] within the tree or -1 if absent.
  int indexOf(PDPage page) {
    final pages = _pages;
    for (var i = 0; i < pages.length; i++) {
      if (identical(pages[i].cosObject, page.cosObject)) {
        return i;
      }
    }
    return -1;
  }

  @override
  Iterator<PDPage> get iterator => _pages.iterator;

  List<PDPage> get _pages => _cachedPages ??= _collectPages(_root);

  void _invalidateCache() {
    _cachedPages = null;
  }

  List<PDPage> _collectPages(COSDictionary node) {
    final List<PDPage> pages = <PDPage>[];
    final type = node.getNameAsString(COSName.type);
    if (type == 'Page') {
      final page = PDPage(node, _resourceCache);
      if (page.parent == null) {
        page.parent = node.getCOSDictionary(COSName.parent);
      }
      pages.add(page);
      return pages;
    }

    if (type != 'Pages') {
      return pages;
    }

    final kids = node.getCOSArray(COSName.kids);
    if (kids == null || kids.isEmpty) {
      return pages;
    }

    for (final child in kids) {
      final dict = _asDictionary(child);
      if (dict == null) {
        continue;
      }
      final childType = dict.getNameAsString(COSName.type);
      if (childType == 'Page') {
        final page = PDPage(dict, _resourceCache);
        if (page.parent == null) {
          page.parent = node;
        }
        pages.add(page);
      } else if (childType == 'Pages') {
        if (dict.getCOSDictionary(COSName.parent) == null) {
          dict[COSName.parent] = node;
        }
        pages.addAll(_collectPages(dict));
      }
    }
    return pages;
  }

  bool _removePage(COSDictionary node, COSDictionary pageDict) {
    final kids = node.getCOSArray(COSName.kids);
    if (kids == null) {
      return false;
    }

    var index = 0;
    while (index < kids.length) {
      final child = kids[index];
      final dict = _asDictionary(child);
      if (dict == null) {
        index++;
        continue;
      }
      final type = dict.getNameAsString(COSName.type);
      if (type == 'Page') {
        if (identical(dict, pageDict)) {
          kids.removeAt(index);
          if (kids.isEmpty) {
            node.removeItem(COSName.kids);
          }
          return true;
        }
        index++;
      } else if (type == 'Pages') {
        final removed = _removePage(dict, pageDict);
        if (removed) {
          if ((dict.getCOSArray(COSName.kids)?.isEmpty ?? true)) {
            kids.removeAt(index);
          }
          return true;
        }
        index++;
      } else {
        index++;
      }
    }
    return false;
  }

  void _updateCounts(COSDictionary node) {
    final pageCount = _calculatePageCount(node);
    node.setInt(COSName.count, pageCount);
    final parent = node.getCOSDictionary(COSName.parent);
    if (parent != null && parent != node) {
      _updateCounts(parent);
    }
  }

  int _calculatePageCount(COSDictionary node) {
    final type = node.getNameAsString(COSName.type);
    if (type == 'Page') {
      return 1;
    }
    if (type != 'Pages') {
      return 0;
    }
    final kids = node.getCOSArray(COSName.kids);
    if (kids == null) {
      return 0;
    }
    var total = 0;
    for (final child in kids) {
      final dict = _asDictionary(child);
      if (dict == null) {
        continue;
      }
      total += _calculatePageCount(dict);
    }
    return total;
  }

  COSArray _ensureKidsArray(COSDictionary node) {
    var kids = node.getCOSArray(COSName.kids);
    if (kids == null) {
      kids = COSArray();
      node[COSName.kids] = kids;
    }
    return kids;
  }

  COSObject _ensureIndirect(COSDictionary dictionary) {
    for (final object in _document.objects) {
      if (identical(object.object, dictionary)) {
        return object;
      }
    }
    return _document.createObject(dictionary);
  }

  int _indexOfChild(COSArray kids, COSDictionary dictionary) {
    for (var i = 0; i < kids.length; i++) {
      final child = kids[i];
      final dict = _asDictionary(child);
      if (dict != null && identical(dict, dictionary)) {
        return i;
      }
    }
    return -1;
  }

  COSDictionary? _asDictionary(COSBase? value) {
    if (value == null || value == COSNull.instance) {
      return null;
    }
    if (value is COSDictionary) {
      return value;
    }
    if (value is COSObject) {
      final obj = value.object;
      if (obj is COSDictionary) {
        return obj;
      }
    }
    return null;
  }
}
