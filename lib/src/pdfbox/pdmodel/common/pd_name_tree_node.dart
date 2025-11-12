import 'dart:collection';

import 'package:logging/logging.dart';

import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_null.dart';
import '../../cos/cos_object.dart';
import '../../cos/cos_string.dart';
import '../../cos/cos_base.dart' show COSBase, COSObjectable;
import '../../../io/exceptions.dart';
import 'cos_array_list.dart';

/// Represents a PDF name tree node (ISO 32000-1, section 7.9.6).
abstract class PDNameTreeNode<T extends COSObjectable>
    implements COSObjectable {
  PDNameTreeNode({COSDictionary? dictionary})
      : _node = dictionary ?? COSDictionary();

  static final Logger _logger = Logger('pdfbox.PDNameTreeNode');

  final COSDictionary _node;
  PDNameTreeNode<T>? _parent;

  @override
  COSDictionary get cosObject => _node;

  PDNameTreeNode<T>? get parent => _parent;

  set parent(PDNameTreeNode<T>? node) {
    _parent = node;
    _calculateLimits();
  }

  bool get isRootNode => _parent == null;

  List<PDNameTreeNode<T>>? get kids {
    final cosKids = _node.getCOSArray(COSName.kids);
    if (cosKids == null) {
      return null;
    }
    final children = <PDNameTreeNode<T>>[];
    for (var i = 0; i < cosKids.length; i++) {
      final entry = _dereference(cosKids.getObject(i));
      PDNameTreeNode<T> child;
      if (entry is COSDictionary) {
        child = createChildNode(entry);
      } else {
        _logger.warning('Bad child node at position $i');
        child = createChildNode(COSDictionary());
      }
      children.add(child);
    }
    return COSArrayList.withArray(children, cosKids);
  }

  void setKids(List<PDNameTreeNode<T>>? kids) {
    if (kids == null || kids.isEmpty) {
      _node.setItem(COSName.kids, null);
      _node.setItem(COSName.names, null);
      _node.setItem(COSName.limits, null);
      _calculateLimits();
      return;
    }
    final array = COSArray();
    for (final child in kids) {
      child.parent = this;
      array.add(child);
    }
    _node[COSName.kids] = array;
    _node.setItem(COSName.names, null);
    _calculateLimits();
  }

  T? getValue(String name) {
    final names = getNames();
    if (names != null) {
      return names[name];
    }
    final children = kids;
    if (children != null) {
      for (final child in children) {
        final upper = child.getUpperLimit();
        final lower = child.getLowerLimit();
        final inconsistent =
            upper != null && lower != null && upper.compareTo(lower) < 0;
        if (inconsistent) {
          continue;
        }
        if ((lower == null || lower.compareTo(name) <= 0) &&
            (upper == null || upper.compareTo(name) >= 0)) {
          final value = child.getValue(name);
          if (value != null) {
            return value;
          }
        }
      }
    } else {
      _logger.warning('NameTreeNode has neither names nor kids.');
    }
    return null;
  }

  Map<String, T?>? getNames() {
    final namesArray = _node.getCOSArray(COSName.names);
    if (namesArray == null) {
      return null;
    }
    final size = namesArray.length;
    if (size % 2 != 0) {
      _logger.warning('Names array has odd size: $size');
    }
    final names = LinkedHashMap<String, T?>();
    for (var i = 0; i + 1 < size; i += 2) {
      final keyBase = _dereference(namesArray.getObject(i));
      if (keyBase is! COSString) {
        throw IOException(
          'Expected string, found $keyBase in name tree at index $i',
        );
      }
      final valueBase = namesArray.getObject(i + 1);
      names[keyBase.string] = convertCOSToPD(valueBase);
    }
    return Map.unmodifiable(names);
  }

  void setNames(Map<String, T?>? names) {
    if (names == null || names.isEmpty) {
      _node.setItem(COSName.names, null);
      _node.setItem(COSName.limits, null);
      _calculateLimits();
      return;
    }
    final keys = names.keys.toList()..sort();
    final array = COSArray();
    for (final key in keys) {
      array.add(COSString(key));
      final value = names[key];
      if (value == null) {
        array.add(COSNull.instance);
      } else {
        array.add(value);
      }
    }
    _node[COSName.names] = array;
    _node.setItem(COSName.kids, null);
    _calculateLimits();
  }

  String? getUpperLimit() => _limitAt(1);

  String? getLowerLimit() => _limitAt(0);

  T? convertCOSToPD(COSBase? base);

  PDNameTreeNode<T> createChildNode(COSDictionary dictionary);

  void _calculateLimits() {
    if (isRootNode) {
      _node.setItem(COSName.limits, null);
      return;
    }
    final children = kids;
    if (children != null && children.isNotEmpty) {
      final first = children.first;
      final last = children.last;
      _setLowerLimit(first.getLowerLimit());
      _setUpperLimit(last.getUpperLimit());
      return;
    }
    final names = getNames();
    if (names != null && names.isNotEmpty) {
      final keys = names.keys.toList();
      _setLowerLimit(keys.first);
      _setUpperLimit(keys.last);
    } else {
      _node.setItem(COSName.limits, null);
    }
  }

  String? _limitAt(int index) {
    final limits = _node.getCOSArray(COSName.limits);
    if (limits == null) {
      return null;
    }
    final value = _dereference(limits.getObject(index));
    if (value is COSString) {
      return value.string;
    }
    return value is COSName ? value.name : null;
  }

  void _setLowerLimit(String? value) => _setLimit(0, value);

  void _setUpperLimit(String? value) => _setLimit(1, value);

  void _setLimit(int index, String? value) {
    var limits = _node.getCOSArray(COSName.limits);
    if (limits == null) {
      limits = COSArray();
      limits.add(COSNull.instance);
      limits.add(COSNull.instance);
      _node[COSName.limits] = limits;
    }
    if (value == null) {
      limits[index] = COSNull.instance;
    } else {
      limits[index] = COSString(value);
    }
  }

  COSBase? _dereference(COSBase? base) {
    if (base is COSObject) {
      return base.object;
    }
    return base;
  }
}
