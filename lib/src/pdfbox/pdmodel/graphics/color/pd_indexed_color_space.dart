import 'dart:typed_data';

import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_number.dart';
import '../../../cos/cos_stream.dart';
import '../../../cos/cos_string.dart';

import 'pd_color.dart';
import 'pd_color_space.dart';

/// Indexed colour space backed by a lookup table and a base colour space.
class PDIndexedColorSpace extends PDColorSpace {
  PDIndexedColorSpace({
    required COSArray array,
    required this.base,
    required this.highValue,
    required Uint8List lookup,
  })  : _array = array,
        _lookup = Uint8List.fromList(lookup);

  final COSArray _array;
  final PDColorSpace base;
  final int highValue;
  final Uint8List _lookup;

  int get _entryLength => base.numberOfComponents;

  @override
  String get name => COSName.indexed.name;

  @override
  int get numberOfComponents => 1;

  @override
  List<double> getDefaultDecode(int bitsPerComponent) =>
      <double>[0.0, highValue.toDouble()];

  @override
  PDColor getInitialColor() => PDColor(const <double>[0.0], this);

  @override
  List<double> toRGB(List<double> value) {
    if (_lookup.isEmpty || _entryLength <= 0) {
      return base.toRGB(base.getInitialColor().components);
    }
    final index = _clampIndex(value.isEmpty ? 0.0 : value[0]);
    final start = index * _entryLength;
    if ((start + _entryLength) > _lookup.length) {
      return base.toRGB(base.getInitialColor().components);
    }
    final components = List<double>.filled(_entryLength, 0.0, growable: false);
    for (var i = 0; i < _entryLength; i++) {
      components[i] = _lookup[start + i] / 255.0;
    }
    return base.toRGB(components);
  }

  int _clampIndex(double raw) {
    var index = raw.isNaN ? 0 : raw.floor();
    if (index < 0) {
      index = 0;
    } else if (index > highValue) {
      index = highValue;
    }
    return index;
  }

  @override
  COSBase get cosObject => _array;

  /// Extracts a lookup byte array from the fourth operand of an Indexed colour
  /// space definition.
  static Uint8List extractLookup(COSBase? value) {
    if (value == null) {
      return Uint8List(0);
    }
    if (value is COSString) {
      return Uint8List.fromList(value.bytes);
    }
    if (value is COSStream) {
      final data = value.decode();
      return data ?? Uint8List(0);
    }
    if (value is COSArray) {
      final bytes = Uint8List(value.length);
      for (var i = 0; i < value.length; i++) {
        final element = value.getObject(i);
        final intValue = element is COSNumber ? element.intValue : 0;
        var clamped = intValue;
        if (clamped < 0) {
          clamped = 0;
        } else if (clamped > 255) {
          clamped = 255;
        }
        bytes[i] = clamped;
      }
      return bytes;
    }
    throw UnsupportedError(
        'Unsupported Indexed colour table type: ${value.runtimeType}');
  }

  /// Reads the high value (HiVal) parameter from the colour space definition.
  static int readHighValue(COSBase? value) {
    if (value is COSNumber) {
      return value.intValue;
    }
    throw StateError('Indexed colour space requires integer HiVal, got $value');
  }
}
