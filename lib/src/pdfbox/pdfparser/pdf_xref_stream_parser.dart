import 'dart:typed_data';

import '../../io/exceptions.dart';
import '../../io/random_access_read.dart';
import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_integer.dart';
import '../cos/cos_name.dart';
import '../cos/cos_object.dart';
import '../cos/cos_object_key.dart';
import '../cos/cos_stream.dart';
import 'xref_trailer_resolver.dart';

class PDFXrefStreamParser {
  PDFXrefStreamParser(COSStream stream)
      : _source = stream.createView() {
    try {
      _initParserValues(stream);
    } on IOException {
      _source.close();
      rethrow;
    } catch (error) {
      _source.close();
      throw IOException(error.toString());
    }
  }

  final List<int> _w = List<int>.filled(3, 0);
  final RandomAccessRead _source;
  late _ObjectNumbers _objectNumbers;

  void parse(XrefTrailerResolver resolver) {
    final entryLength = _w[0] + _w[1] + _w[2];
    if (entryLength <= 0) {
      return;
    }
    final buffer = Uint8List(entryLength);
    try {
      while (!_source.isEOF && _objectNumbers.hasNext) {
        _readNextValue(buffer);
        final objId = _objectNumbers.next();
        final type = _w[0] == 0 ? 1 : _parseValue(buffer, 0, _w[0]);
        if (type == 0) {
          continue;
        }
        final offset = _parseValue(buffer, _w[0], _w[1]);
        final third = _parseValue(buffer, _w[0] + _w[1], _w[2]);
        if (type == 1) {
          resolver.setXRef(COSObjectKey(objId, third), offset);
        } else if (type == 2) {
          resolver.setXRef(COSObjectKey(objId, 0, third), -offset);
        }
      }
    } finally {
      close();
    }
  }

  void close() {
    _source.close();
  }

  void _initParserValues(COSStream stream) {
    final wArray = stream.getCOSArray(COSName.w);
    if (wArray == null) {
      throw IOException('/W array is missing in Xref stream');
    }
    if (wArray.length != 3) {
      throw IOException('Wrong number of values for /W array in Xref stream');
    }
    for (var i = 0; i < 3; i++) {
      final value = wArray.getInt(i, 0);
      if (value == null) {
        throw IOException('Invalid /W entry at index $i in Xref stream');
      }
      if (value < 0) {
        throw IOException('Negative /W value in Xref stream');
      }
      _w[i] = value;
    }
    if (_w[0] + _w[1] + _w[2] > 20) {
      throw IOException('Incorrect /W array in Xref stream');
    }

    var indexArray = stream.getCOSArray(COSName.index);
    if (indexArray == null) {
      indexArray = COSArray();
      indexArray.addObject(COSInteger.valueOf(0));
      indexArray.addObject(COSInteger.valueOf(stream.getInt(COSName.size) ?? 0));
    }
    if (indexArray.isEmpty || indexArray.length % 2 == 1) {
      throw IOException('Wrong number of values for /Index array in Xref stream');
    }
    _objectNumbers = _ObjectNumbers(indexArray);
  }

  void _readNextValue(Uint8List value) {
    var remaining = value.length;
    var offset = 0;
    while (remaining > 0 && !_source.isEOF) {
      final read = _source.readBuffer(value, offset, remaining);
      if (read <= 0) {
        break;
      }
      offset += read;
      remaining -= read;
    }
  }

  int _parseValue(Uint8List data, int start, int length) {
    if (length <= 0) {
      return 0;
    }
    var result = 0;
    for (var i = 0; i < length; i++) {
      result = (result << 8) | (data[start + i] & 0xff);
    }
    return result;
  }
}

class _ObjectNumbers {
  _ObjectNumbers(COSArray indexArray) {
    final ranges = <_Range>[];
    for (var i = 0; i < indexArray.length; i += 2) {
      final startBase = indexArray.getObject(i);
      final countBase = indexArray.getObject(i + 1);
      final startValue = _asInt(startBase);
      final countValue = _asInt(countBase);
      ranges.add(_Range(startValue, startValue + countValue));
    }
    _ranges = ranges;
    if (ranges.isEmpty) {
      _currentRange = null;
    } else {
      _currentRange = ranges.first;
      _currentNumber = _currentRange!.start;
    }
  }

  late final List<_Range> _ranges;
  _Range? _currentRange;
  int _currentNumber = 0;

  bool get hasNext {
    final range = _currentRange;
    if (range == null) {
      return false;
    }
    if (_currentNumber < range.end) {
      return true;
    }
    final index = _ranges.indexOf(range);
    return index >= 0 && index < _ranges.length - 1;
  }

  int next() {
    final range = _currentRange;
    if (range == null) {
      throw StateError('No more object numbers');
    }
    if (_currentNumber < range.end) {
      return _currentNumber++;
    }
    final index = _ranges.indexOf(range) + 1;
    if (index >= _ranges.length) {
      throw StateError('No more object numbers');
    }
    _currentRange = _ranges[index];
    _currentNumber = _currentRange!.start;
    return _currentNumber++;
  }

  int _asInt(COSBase base) {
    final resolved = base is COSObject ? base.object : base;
    if (resolved is COSInteger) {
      return resolved.intValue;
    }
    throw IOException('Xref stream must have integer in /Index array');
  }
}

class _Range {
  _Range(this.start, this.end);

  final int start;
  final int end;
}
