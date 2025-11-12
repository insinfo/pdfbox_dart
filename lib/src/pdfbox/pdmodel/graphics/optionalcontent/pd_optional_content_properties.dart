import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_null.dart';
import '../../../cos/cos_object.dart';
import '../../documentinterchange/markedcontent/pd_property_list.dart';

/// Represents the optional content properties dictionary (PDF 1.5).
class PDOptionalContentProperties implements COSObjectable {
  PDOptionalContentProperties() : _dict = COSDictionary() {
    _dict[COSName.ocgs] = COSArray();
    final d = COSDictionary();
    d.setString(COSName.nameKey, 'Top');
    _dict[COSName.d] = d;
  }

  PDOptionalContentProperties.fromDictionary(this._dict);

  final COSDictionary _dict;

  @override
  COSDictionary get cosObject => _dict;

  /// Describes the base state entry within the /D configuration dictionary.
  BaseState get baseState {
    final d = _getD();
    final name = d.getCOSName(COSName.baseState) ?? COSName.on;
    return BaseState.fromCOSName(name);
  }

  set baseState(BaseState state) {
    final d = _getD();
    d[COSName.baseState] = state.cosName;
  }

  /// Returns the first optional content group with the given [name], if any.
  PDOptionalContentGroup? getGroup(String name) {
    final ocgs = _getOCGs();
    for (final entry in ocgs) {
      final dictionary = _toDictionary(entry);
      if (dictionary == null) {
        continue;
      }
      final groupName = dictionary.getString(COSName.nameKey);
      if (groupName == name) {
        return PDOptionalContentGroup.fromDictionary(dictionary);
      }
    }
    return null;
  }

  /// Adds an optional content group to the document configuration.
  void addGroup(PDOptionalContentGroup group) {
    final ocgs = _getOCGs();
    ocgs.add(group.cosObject);

    final d = _getD();
    var order = d.getCOSArray(COSName.order);
    order ??= COSArray();
    if (order.isEmpty) {
      d[COSName.order] = order;
    }
    order.add(group);
  }

  /// Returns all optional content groups present in this document.
  Iterable<PDOptionalContentGroup> get optionalContentGroups sync* {
    final ocgs = _getOCGs();
    for (final entry in ocgs) {
      final dictionary = _toDictionary(entry);
      if (dictionary != null) {
        yield PDOptionalContentGroup.fromDictionary(dictionary);
      }
    }
  }

  /// Lists the names of all optional content groups in document order.
  List<String> get groupNames {
    final ocgs = _dict.getCOSArray(COSName.ocgs);
    if (ocgs == null) {
      return const <String>[];
    }
    final result = <String>[];
    for (var i = 0; i < ocgs.length; ++i) {
      final dictionary = _toDictionary(ocgs.getObject(i));
      result.add(dictionary?.getString(COSName.nameKey) ?? '');
    }
    return result;
  }

  /// Indicates whether a group with the provided [name] exists.
  bool hasGroup(String name) => groupNames.contains(name);

  /// Indicates whether at least one group with [name] is enabled.
  bool isGroupEnabledByName(String name) {
    for (final entry in _getOCGs()) {
      final dictionary = _toDictionary(entry);
      if (dictionary == null) {
        continue;
      }
      final groupName = dictionary.getString(COSName.nameKey);
      if (groupName == name &&
          isGroupEnabled(PDOptionalContentGroup.fromDictionary(dictionary))) {
        return true;
      }
    }
    return false;
  }

  /// Indicates whether the provided [group] is currently enabled.
  bool isGroupEnabled(PDOptionalContentGroup? group) {
    final state = baseState;
    var enabled = state != BaseState.off;
    if (group == null) {
      return enabled;
    }

    final d = _getD();
    final on = d.getCOSArray(COSName.on);
    if (on != null && _containsGroup(on, group)) {
      return true;
    }
    final off = d.getCOSArray(COSName.off);
    if (off != null && _containsGroup(off, group)) {
      return false;
    }
    return enabled;
  }

  /// Enables or disables all groups matching [name].
  bool setGroupEnabledByName(String name, bool enable) {
    var found = false;
    for (final entry in _getOCGs()) {
      final dictionary = _toDictionary(entry);
      if (dictionary == null) {
        continue;
      }
      if (dictionary.getString(COSName.nameKey) == name &&
          setGroupEnabled(
            PDOptionalContentGroup.fromDictionary(dictionary),
            enable,
          )) {
        found = true;
      }
    }
    return found;
  }

  /// Enables or disables [group], returning whether it previously had an explicit state.
  bool setGroupEnabled(PDOptionalContentGroup group, bool enable) {
    final d = _getD();
    var on = d.getCOSArray(COSName.on);
    on ??= COSArray();
    if (d.getCOSArray(COSName.on) == null) {
      d[COSName.on] = on;
    }
    var off = d.getCOSArray(COSName.off);
    off ??= COSArray();
    if (d.getCOSArray(COSName.off) == null) {
      d[COSName.off] = off;
    }

    final target = group.cosObject;
    var found = false;
    if (enable) {
      for (var i = 0; i < off.length; ++i) {
        final dictionary = _toDictionary(off.getObject(i));
        if (dictionary == target) {
          off.removeAt(i);
          on.add(target);
          found = true;
          break;
        }
      }
    } else {
      for (var i = 0; i < on.length; ++i) {
        final dictionary = _toDictionary(on.getObject(i));
        if (dictionary == target) {
          on.removeAt(i);
          off.add(target);
          found = true;
          break;
        }
      }
    }
    if (!found) {
      if (enable) {
        on.add(target);
      } else {
        off.add(target);
      }
    }
    return found;
  }

  COSArray _getOCGs() {
    var ocgs = _dict.getCOSArray(COSName.ocgs);
    ocgs ??= COSArray();
    if (_dict.getCOSArray(COSName.ocgs) == null) {
      _dict[COSName.ocgs] = ocgs;
    }
    return ocgs;
  }

  COSDictionary _getD() {
    var d = _dict.getCOSDictionary(COSName.d);
    if (d == null) {
      d = COSDictionary();
      d.setString(COSName.nameKey, 'Top');
      _dict[COSName.d] = d;
    }
    return d;
  }

  COSDictionary? _toDictionary(COSBase? base) {
    final resolved = _dereference(base);
    return resolved is COSDictionary ? resolved : null;
  }

  bool _containsGroup(COSArray array, PDOptionalContentGroup group) {
    for (var i = 0; i < array.length; ++i) {
      final dictionary = _toDictionary(array.getObject(i));
      if (dictionary == group.cosObject) {
        return true;
      }
    }
    return false;
  }

  COSBase? _dereference(COSBase? base) {
    if (base is COSObject) {
      return base.object;
    }
    if (base is COSNull) {
      return null;
    }
    return base;
  }
}

/// Enumeration of base states for optional content configuration dictionaries.
enum BaseState {
  on('ON'),
  off('OFF'),
  unchanged('Unchanged');

  const BaseState(this._value);

  final String _value;

  COSName get cosName => COSName(_value);

  static BaseState fromCOSName(COSName? name) {
    if (name == COSName.off) {
      return BaseState.off;
    }
    if (name == COSName.unchanged) {
      return BaseState.unchanged;
    }
    return BaseState.on;
  }
}
