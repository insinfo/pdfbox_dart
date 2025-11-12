import 'package:logging/logging.dart';

import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_integer.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_null.dart';
import '../../cos/cos_object.dart';
import '../../cos/cos_base.dart' show COSBase, COSObjectable;
import 'cos_array_list.dart';

typedef PDNumberTreeValueFactory<T extends COSObjectable> = T? Function(
  COSBase base,
);

/// Represents a PDF number tree node (PDF 32000-1:2008, section 7.9.7).
class PDNumberTreeNode<T extends COSObjectable> implements COSObjectable {
  PDNumberTreeNode({
    COSDictionary? dictionary,
    PDNumberTreeValueFactory<T>? valueFactory,
  })  : _node = dictionary ?? COSDictionary(),
        _valueFactory = valueFactory ?? _identityFactory<T>();

  static final Logger _logger = Logger('pdfbox.PDNumberTreeNode');

  final COSDictionary _node;
  final PDNumberTreeValueFactory<T> _valueFactory;

  @override
  COSDictionary get cosObject => _node;

  List<PDNumberTreeNode<T>>? get kids {
    final cosKids = _node.getCOSArray(COSName.kids);
    if (cosKids == null) {
      return null;
    }
    final children = <PDNumberTreeNode<T>>[];
    for (var i = 0; i < cosKids.length; i++) {
      final entry = cosKids.getObject(i);
      if (entry is COSDictionary) {
        children.add(
          PDNumberTreeNode<T>(dictionary: entry, valueFactory: _valueFactory),
        );
      } else {
        _logger.warning('Bad child node at position $i');
        children.add(PDNumberTreeNode<T>(valueFactory: _valueFactory));
      }
    }
    return COSArrayList.withArray(children, cosKids);
  }

  void setKids(List<PDNumberTreeNode<T>>? kids) {
    if (kids == null || kids.isEmpty) {
      if (_node.getDictionaryObject(COSName.nums) == null) {
        _node.setItem(COSName.kids, null);
        _node.setItem(COSName.limits, null);
      } else {
        _node.setItem(COSName.kids, null);
      }
      return;
    }

    final array = COSArray();
    for (final kid in kids) {
      array.add(kid);
    }
    _node[COSName.kids] = array;
    _setLowerLimit(kids.first.getLowerLimit());
    _setUpperLimit(kids.last.getUpperLimit());
  }

  Map<int, T?>? get numbers {
    final cosNumbers = _node.getCOSArray(COSName.nums);
    if (cosNumbers == null) {
      return null;
    }
    final size = cosNumbers.length;
    if (size % 2 != 0) {
      _logger.warning('Numbers array has odd size: $size');
    }
    final result = <int, T?>{};
    for (var i = 0; i + 1 < size; i += 2) {
      final keyBase = cosNumbers.getObject(i);
      final keyObject = keyBase is COSObject ? keyBase.object : keyBase;
      if (keyObject is! COSInteger) {
        _logger.warning('Expected integer at index $i but found $keyObject');
        return null;
      }
      final valueObject = cosNumbers.getObject(i + 1);
      result[keyObject.intValue] = _convertToPD(valueObject);
    }
    return Map.unmodifiable(result);
  }

  void setNumbers(Map<int, T?>? numbers) {
    if (numbers == null || numbers.isEmpty) {
      _node.setItem(COSName.nums, null);
      _node.setItem(COSName.limits, null);
      return;
    }
    final keys = numbers.keys.toList()..sort();
    final array = COSArray();
    for (final key in keys) {
      array.add(COSInteger(key));
      final value = numbers[key];
      if (value == null) {
        array.add(COSNull.instance);
      } else {
        array.add(value);
      }
    }
    _setLowerLimit(keys.first);
    _setUpperLimit(keys.last);
  _node[COSName.nums] = array;
  }

  T? getValue(int index) {
    final map = numbers;
    if (map != null) {
      return map[index];
    }
    final children = kids;
    if (children != null) {
      for (final child in children) {
        final lower = child.getLowerLimit();
        final upper = child.getUpperLimit();
        if (lower != null && upper != null && lower > upper) {
          continue;
        }
        if ((lower == null || lower <= index) &&
            (upper == null || upper >= index)) {
          final value = child.getValue(index);
          if (value != null) {
            return value;
          }
        }
      }
    } else {
      _logger.warning('NumberTreeNode has neither numbers nor kids.');
    }
    return null;
  }

  int? getLowerLimit() => _limitAt(0);

  int? getUpperLimit() => _limitAt(1);

  int? _limitAt(int index) {
  final limits = _node.getCOSArray(COSName.limits);
    if (limits == null) {
      return null;
    }
    final value = limits.getObject(index);
    if (value is COSInteger) {
      return value.intValue;
    }
    return null;
  }

  void _setLowerLimit(int? value) => _setLimit(0, value);

  void _setUpperLimit(int? value) => _setLimit(1, value);

  void _setLimit(int index, int? value) {
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
      limits[index] = COSInteger(value);
    }
  }

  T? _convertToPD(COSBase? base) {
    if (base == null || base is COSNull) {
      return null;
    }
    final resolved = base is COSObject ? base.object : base;
    if (resolved is COSNull) {
      return null;
    }
    return _valueFactory(resolved);
  }

  static PDNumberTreeValueFactory<T> _identityFactory<T extends COSObjectable>() {
    return (COSBase base) => base is T ? base as T : null;
  }
}
