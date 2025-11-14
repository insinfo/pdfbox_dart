import 'dart:collection';
import 'dart:typed_data';

import '../cos/cos_array.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_integer.dart';
import '../cos/cos_name.dart';
import '../cos/cos_stream.dart';
import 'xref/free_x_reference.dart';
import 'xref/x_reference_entry.dart';

/// Builder for cross-reference streams mirroring PDFBox's PDFXRefStream.
///
/// TODO: integrate with the writer once the remaining COSWriter parity tasks are ported.
class PDFXRefStream {
  PDFXRefStream() : _stream = COSStream();

  final COSStream _stream;
  final List<XReferenceEntry> _entries = <XReferenceEntry>[];
  final SplayTreeSet<int> _objectNumbers = SplayTreeSet<int>()..add(0);
  int? _size;

  COSStream get stream => _stream;

  void setSize(int size) {
    _size = size;
  }

  void addTrailerInfo(COSDictionary trailer) {
    final encryptName = COSName.get('Encrypt');
    for (final entry in trailer.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == COSName.info ||
          key == COSName.root ||
          key == encryptName ||
          key == COSName.id ||
          key == COSName.prev) {
        _stream.setItem(key, value);
      }
    }
  }

  void addEntry(XReferenceEntry entry) {
    final key = entry.referencedKey;
    if (key == null) {
      return;
    }
    if (_objectNumbers.contains(key.objectNumber)) {
      return;
    }
    _objectNumbers.add(key.objectNumber);
    _entries.add(entry);
  }

  COSStream build() {
    final size = _size;
    if (size == null) {
      throw StateError('xref stream size not set');
    }

    final entries = List<XReferenceEntry>.from(_entries)
      ..sort();

    final widths = _computeFieldWidths(entries);

    _stream.setItem(COSName.type, COSName.xref);
    _stream.setInt(COSName.size, size);
    _stream.setItem(COSName.index, _buildIndexArray());
    _stream.setItem(COSName.w, _toCOSIntegerArray(widths));

    _stream.data = _buildStreamData(entries, widths);

    for (final name in List<COSName>.from(_stream.keys)) {
      if (name == COSName.root ||
          name == COSName.info ||
          name == COSName.prev ||
          name == COSName.get('Encrypt')) {
        continue;
      }
      final value = _stream.getItem(name);
      if (value != null) {
        value.isDirect = true;
      }
    }

    return _stream;
  }

  COSArray _buildIndexArray() {
    final indices = <int>[];
    int? start;
    int length = 0;
    final numbers = List<int>.from(_objectNumbers);
    for (final number in numbers) {
      if (start == null) {
        start = number;
        length = 1;
        continue;
      }
      if (start + length == number) {
        length++;
      } else {
        indices..add(start)..add(length);
        start = number;
        length = 1;
      }
    }
    if (start != null) {
      indices..add(start)..add(length);
    }
    final array = COSArray();
    for (final value in indices) {
      array.addObject(COSInteger.valueOf(value));
    }
    return array;
  }

  List<int> _computeFieldWidths(List<XReferenceEntry> entries) {
    final maxValues = List<int>.filled(3, 0);
    for (final entry in entries) {
      if (entry.firstColumnValue > maxValues[0]) {
        maxValues[0] = entry.firstColumnValue;
      }
      if (entry.secondColumnValue > maxValues[1]) {
        maxValues[1] = entry.secondColumnValue;
      }
      if (entry.thirdColumnValue > maxValues[2]) {
        maxValues[2] = entry.thirdColumnValue;
      }
    }

    final widths = List<int>.filled(3, 0);
    for (var i = 0; i < 3; i++) {
      var value = maxValues[i];
      while (value > 0) {
        widths[i]++;
        value >>= 8;
      }
    }
    return widths;
  }

  COSArray _toCOSIntegerArray(List<int> values) {
    final array = COSArray();
    for (final value in values) {
      array.addObject(COSInteger.valueOf(value));
    }
    return array;
  }

  Uint8List _buildStreamData(List<XReferenceEntry> entries, List<int> widths) {
    final builder = BytesBuilder(copy: false);
    builder.add(_encodeEntry(FreeXReference.nullEntry, widths));
    for (final entry in entries) {
      if (identical(entry, FreeXReference.nullEntry)) {
        continue;
      }
      builder.add(_encodeEntry(entry, widths));
    }
    return builder.takeBytes();
  }

  List<int> _encodeEntry(XReferenceEntry entry, List<int> widths) {
    final data = Uint8List(widths[0] + widths[1] + widths[2]);
    var offset = 0;
    offset += _writeNumber(entry.firstColumnValue, widths[0], data, offset);
    offset += _writeNumber(entry.secondColumnValue, widths[1], data, offset);
    _writeNumber(entry.thirdColumnValue, widths[2], data, offset);
    return data;
  }

  int _writeNumber(int value, int width, Uint8List target, int offset) {
    if (width <= 0) {
      return 0;
    }
    for (var i = width - 1; i >= 0; i--) {
      target[offset + i] = value & 0xff;
      value >>= 8;
    }
    return width;
  }
}
