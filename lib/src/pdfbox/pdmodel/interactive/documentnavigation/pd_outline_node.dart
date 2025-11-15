import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_string.dart';
import '../../common/pd_destination.dart';
import '../action/pd_action.dart';
import '../action/pd_action_factory.dart';

/// Shared implementation for outline nodes (ISO 32000-1, §12.3.3).
abstract class PDOutlineNode<T extends PDOutlineItem> {
  PDOutlineNode(this._dictionary)
      : _openStateCache = _deriveOpenState(_dictionary) {
    _nodeCache[_dictionary] = this;
  }

  static final Expando<PDOutlineNode<dynamic>> _nodeCache =
      Expando<PDOutlineNode<dynamic>>('pdfbox_outline_node_cache');

  final COSDictionary _dictionary;
  T? _firstChildCache;
  T? _lastChildCache;
  bool? _openStateCache;

  static bool? _deriveOpenState(COSDictionary dictionary) {
    final count = dictionary.getInt(COSName.count);
    if (count == null) {
      return null;
    }
    return count >= 0;
  }

  COSDictionary get cosObject => _dictionary;

  /// Returns `true` when the node is open or when `/Count` is missing.
  bool get open {
    final cached = _openStateCache;
    if (cached != null) {
      return cached;
    }
    final count = _dictionary.getInt(COSName.count);
    final computed = count == null || count >= 0;
    _openStateCache = computed;
    return computed;
  }

  set open(bool value) {
    if (value == open) {
      return;
    }
    _openStateCache = value;
    if (!_hasChildren) {
      _dictionary.removeItem(COSName.count);
      return;
    }
    if (value) {
      final openDescendants = _openDescendantCount();
      if (openDescendants == 0) {
        _dictionary.removeItem(COSName.count);
      } else {
        _dictionary.setInt(COSName.count, openDescendants);
      }
    } else {
      final totalDescendants = _totalDescendantCount();
      if (totalDescendants == 0) {
        _dictionary.removeItem(COSName.count);
      } else {
        _dictionary.setInt(COSName.count, -totalDescendants);
      }
    }
    _propagateCountChanges();
    _openStateCache = value;
  }

  int? get openCount => _dictionary.getInt(COSName.count);

  Iterable<T> get children sync* {
    var current = firstChild;
    final visited = <COSDictionary>{};
    while (current != null) {
      if (!visited.add(current.cosObject)) {
        break;
      }
      yield current;
      current = current.nextSibling as T?;
    }
  }

  bool get hasChildren => firstChild != null;

  T? get firstChild {
    final cached = _firstChildCache;
    if (cached != null) {
      return cached;
    }
    final childDict = _dictionary.getCOSDictionary(COSName.first);
    final child = childDict == null ? null : _wrapChild(childDict);
    _firstChildCache = child;
    return child;
  }

  T? get lastChild {
    final cached = _lastChildCache;
    if (cached != null) {
      return cached;
    }
    final childDict = _dictionary.getCOSDictionary(COSName.last);
    final child = childDict == null ? null : _wrapChild(childDict);
    _lastChildCache = child;
    return child;
  }

  void addLast(T child) => _insertAfter(lastChild, child);

  void addFirst(T child) => _insertAfter(null, child);

  void _insertAfter(PDOutlineItem? previous, T child) {
    if (identical(previous, child)) {
      return;
    }
    child.remove();

    final PDOutlineItem? next =
        previous == null ? firstChild : previous.nextSibling;

    child._setParent(this);

    if (previous != null) {
      previous._setNextSibling(child);
    } else {
      child._setPreviousSibling(null);
      _setFirstChild(child);
    }

    if (next != null) {
      next._setPreviousSibling(child);
    } else {
      child._setNextSibling(null);
      _setLastChild(child);
    }

    if (_firstChildCache == null) {
      _setFirstChild(child);
    }
    if (_lastChildCache == null) {
      _setLastChild(child);
    }

    _propagateCountChanges();
  }

  void _setFirstChild(T? child) {
    _firstChildCache = child;
    if (child == null) {
      _dictionary.removeItem(COSName.first);
    } else {
      _dictionary.setItem(COSName.first, child.cosObject);
    }
  }

  void _setLastChild(T? child) {
    _lastChildCache = child;
    if (child == null) {
      _dictionary.removeItem(COSName.last);
    } else {
      _dictionary.setItem(COSName.last, child.cosObject);
    }
  }

  void _propagateCountChanges() {
    _updateOwnCount();
    var ancestor = parentNode;
    while (ancestor != null) {
      ancestor._updateOwnCount();
      ancestor._openStateCache =
          _deriveOpenState(ancestor._dictionary) ?? ancestor._openStateCache;
      ancestor = ancestor.parentNode;
    }
  }

  void _updateOwnCount() {
    if (!_hasChildren) {
      _dictionary.removeItem(COSName.count);
      _openStateCache = null;
      return;
    }
    final totalDescendants = _totalDescendantCount();
    if (totalDescendants == 0) {
      _dictionary.removeItem(COSName.count);
      _openStateCache = null;
      return;
    }
    if (open) {
      final openDescendants = _openDescendantCount();
      if (openDescendants == 0) {
        _dictionary.removeItem(COSName.count);
        _openStateCache = null;
      } else {
        _dictionary.setInt(COSName.count, openDescendants);
        _openStateCache = true;
      }
    } else {
      _dictionary.setInt(COSName.count, -totalDescendants);
      _openStateCache = false;
    }
  }

  bool get _hasChildren =>
      _dictionary.getDictionaryObject(COSName.first) != null;

  int _totalDescendantCount() {
    var total = 0;
    for (final child in children) {
      total += 1 + child._totalDescendantCount();
    }
    return total;
  }

  int _openDescendantCount() {
    var total = 0;
    for (final child in children) {
      total += 1;
      if (child.open) {
        total += child._openDescendantCount();
      }
    }
    return total;
  }

  T _wrapChild(COSDictionary dictionary) {
    final cached = _nodeCache[dictionary];
    final T child = cached is T ? cached : createChild(dictionary);
    final PDOutlineItem item = child as PDOutlineItem;
    item._parentCache ??= this;
    final prevDict = dictionary.getCOSDictionary(COSName.prev);
    if (prevDict != null && item._previousCache == null) {
      final prevExisting = _nodeCache[prevDict];
      item._previousCache = prevExisting is PDOutlineItem
          ? prevExisting
          : PDOutlineItem._(prevDict);
    }
    final nextDict = dictionary.getCOSDictionary(COSName.next);
    if (nextDict != null && item._nextCache == null) {
      final nextExisting = _nodeCache[nextDict];
      item._nextCache = nextExisting is PDOutlineItem
          ? nextExisting
          : PDOutlineItem._(nextDict);
    }
    return child;
  }

  T createChild(COSDictionary dictionary);

  PDOutlineNode<dynamic>? get parentNode;
}

class PDOutlineRoot extends PDOutlineNode<PDOutlineItem> {
  factory PDOutlineRoot({COSDictionary? dictionary}) {
    final dict = dictionary ?? _createRootDictionary();
    final existing = PDOutlineNode._nodeCache[dict];
    if (existing is PDOutlineRoot) {
      return existing;
    }
    if (dict.getNameAsString(COSName.type) != 'Outlines') {
      dict.setName(COSName.type, 'Outlines');
    }
    return PDOutlineRoot._(dict);
  }

  PDOutlineRoot._(COSDictionary dictionary) : super(dictionary);

  static COSDictionary _createRootDictionary() {
    final dict = COSDictionary();
    dict.setName(COSName.type, 'Outlines');
    return dict;
  }

  @override
  PDOutlineNode<dynamic>? get parentNode => null;

  @override
  PDOutlineItem createChild(COSDictionary dictionary) =>
      PDOutlineItem._(dictionary);
}

class PDOutlineItem extends PDOutlineNode<PDOutlineItem> {
  factory PDOutlineItem({COSDictionary? dictionary}) {
    final dict = dictionary ?? COSDictionary();
    final existing = PDOutlineNode._nodeCache[dict];
    if (existing is PDOutlineItem) {
      return existing;
    }
    return PDOutlineItem._(dict);
  }

  PDOutlineItem._(COSDictionary dictionary) : super(dictionary);

  PDOutlineNode<dynamic>? _parentCache;
  PDOutlineItem? _previousCache;
  PDOutlineItem? _nextCache;

  @override
  PDOutlineItem createChild(COSDictionary dictionary) =>
      PDOutlineItem._(dictionary);

  @override
  PDOutlineNode<dynamic>? get parentNode {
    if (_parentCache != null) {
      return _parentCache;
    }
    final parentDict = cosObject.getCOSDictionary(COSName.parent);
    if (parentDict == null) {
      return null;
    }
    final existing = PDOutlineNode._nodeCache[parentDict];
    if (existing != null) {
      _parentCache = existing;
      return existing;
    }
    if (parentDict.getNameAsString(COSName.type) == 'Outlines') {
      final root = PDOutlineRoot._(parentDict);
      _parentCache = root;
      return root;
    }
    final parent = PDOutlineItem._(parentDict);
    _parentCache = parent;
    return parent;
  }

  PDOutlineItem? get previousSibling {
    if (_previousCache != null) {
      return _previousCache;
    }
    final prevDict = cosObject.getCOSDictionary(COSName.prev);
    if (prevDict == null) {
      return null;
    }
    final existing = PDOutlineNode._nodeCache[prevDict];
    if (existing is PDOutlineItem) {
      _previousCache = existing;
      return existing;
    }
    final sibling = PDOutlineItem._(prevDict);
    _previousCache = sibling;
    return sibling;
  }

  PDOutlineItem? get nextSibling {
    if (_nextCache != null) {
      return _nextCache;
    }
    final nextDict = cosObject.getCOSDictionary(COSName.next);
    if (nextDict == null) {
      return null;
    }
    final existing = PDOutlineNode._nodeCache[nextDict];
    if (existing is PDOutlineItem) {
      _nextCache = existing;
      return existing;
    }
    final sibling = PDOutlineItem._(nextDict);
    _nextCache = sibling;
    return sibling;
  }

  String? get title => cosObject.getString(COSName.title);

  set title(String? value) => cosObject.setString(COSName.title, value);

  List<double>? get color {
    final array = cosObject.getCOSArray(COSName.c);
    if (array == null) {
      return null;
    }
    final values = array.toDoubleList();
    if (values.length < 3) {
      return null;
    }
    return List<double>.unmodifiable(values.take(3));
  }

  set color(List<double>? value) {
    if (value == null) {
      cosObject.removeItem(COSName.c);
      return;
    }
    if (value.length != 3) {
      throw ArgumentError.value(value, 'value', 'Outline color must have exactly 3 components');
    }
    final components = value.map((component) => component.toDouble()).toList(growable: false);
    final array = COSArray()
      ..add(COSFloat(components[0]))
      ..add(COSFloat(components[1]))
      ..add(COSFloat(components[2]));
    cosObject.setItem(COSName.c, array);
  }

  bool get isItalic => cosObject.getFlag(COSName.f, 1);

  set isItalic(bool value) => cosObject.setFlag(COSName.f, 1, value);

  bool get isBold => cosObject.getFlag(COSName.f, 2);

  set isBold(bool value) => cosObject.setFlag(COSName.f, 2, value);

  PDDestination? get destination =>
      PDDestination.fromCOS(cosObject.getDictionaryObject(COSName.dest));

  set destination(PDDestination? value) =>
      cosObject.setItem(COSName.dest, value?.cosObject);

  String? get destinationName {
    final base = cosObject.getDictionaryObject(COSName.dest);
    if (base is COSName) {
      return base.name;
    }
    if (base is COSString) {
      return base.string;
    }
    return null;
  }

  set destinationName(String? value) {
    if (value == null) {
      cosObject.removeItem(COSName.dest);
    } else {
      cosObject.setString(COSName.dest, value);
    }
  }

  PDAction? get action =>
      PDActionFactory.instance.createAction(cosObject.getDictionaryObject(COSName.a));

  set action(PDAction? value) => cosObject.setItem(COSName.a, value?.cosObject);

  COSDictionary? get structureElement => cosObject.getCOSDictionary(COSName.se);

  set structureElement(COSDictionary? value) => cosObject.setItem(COSName.se, value);

  void remove() {
    final parentNodeRef = parentNode;
    if (parentNodeRef == null) {
      return;
    }
    final prev = previousSibling;
    final next = nextSibling;

    final parentOutline = parentNodeRef as PDOutlineNode<PDOutlineItem>;
    if (identical(parentOutline.firstChild, this)) {
      parentOutline._setFirstChild(next);
    }
    if (identical(parentOutline.lastChild, this)) {
      parentOutline._setLastChild(prev);
    }

    if (prev != null) {
      if (next == null) {
        prev.cosObject.removeItem(COSName.next);
      } else {
        prev.cosObject.setItem(COSName.next, next.cosObject);
      }
      prev._nextCache = next;
    }
    if (next != null) {
      if (prev == null) {
        next.cosObject.removeItem(COSName.prev);
      } else {
        next.cosObject.setItem(COSName.prev, prev.cosObject);
      }
      next._previousCache = prev;
    }

    cosObject.removeItem(COSName.parent);
    cosObject.removeItem(COSName.prev);
    cosObject.removeItem(COSName.next);

    _parentCache = null;
    _previousCache = null;
    _nextCache = null;

    parentOutline._propagateCountChanges();
  }

  void _setParent(PDOutlineNode<dynamic> parent) {
    _parentCache = parent;
    cosObject.setItem(COSName.parent, parent.cosObject);
  }

  void _setNextSibling(PDOutlineItem? sibling) {
    _nextCache = sibling;
    if (sibling == null) {
      cosObject.removeItem(COSName.next);
    } else {
      cosObject.setItem(COSName.next, sibling.cosObject);
      sibling._previousCache = this;
      sibling.cosObject.setItem(COSName.prev, cosObject);
    }
  }

  void _setPreviousSibling(PDOutlineItem? sibling) {
    _previousCache = sibling;
    if (sibling == null) {
      cosObject.removeItem(COSName.prev);
    } else {
      cosObject.setItem(COSName.prev, sibling.cosObject);
      sibling._nextCache = this;
      sibling.cosObject.setItem(COSName.next, cosObject);
    }
  }
}
