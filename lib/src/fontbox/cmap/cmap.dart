import 'dart:typed_data';

import '../../io/random_access_read.dart';
import 'cid_range.dart';
import 'cmap_strings.dart';
import 'codespace_range.dart';

/// Representation of a CMap file.
class CMap {
  int _wMode = 0;
  String? _name;
  String? _version;
  int _type = -1;

  String? _registry;
  String? _ordering;
  int _supplement = 0;

  int _minCodeLength = 4;
  int _maxCodeLength = 0;

  int _minCidLength = 4;
  int _maxCidLength = 0;

  final List<CodespaceRange> _codespaceRanges = <CodespaceRange>[];

  final Map<int, String> _charToUnicodeOneByte = <int, String>{};
  final Map<int, String> _charToUnicodeTwoBytes = <int, String>{};
  final Map<int, String> _charToUnicodeMoreBytes = <int, String>{};

  final Map<int, Map<int, int>> _codeToCid = <int, Map<int, int>>{};
  final List<CidRange> _codeToCidRanges = <CidRange>[];

  final Map<String, Uint8List> _unicodeToByteCodes = <String, Uint8List>{};

  static const String _space = ' ';
  int _spaceMapping = -1;

  CMap();

  bool hasCIDMappings() => _codeToCid.isNotEmpty || _codeToCidRanges.isNotEmpty;

  bool hasUnicodeMappings() =>
      _charToUnicodeOneByte.isNotEmpty ||
      _charToUnicodeTwoBytes.isNotEmpty ||
      _charToUnicodeMoreBytes.isNotEmpty;

  String? toUnicode(int code, [int? length]) {
    if (length != null) {
      switch (length) {
        case 1:
          return _charToUnicodeOneByte[code];
        case 2:
          return _charToUnicodeTwoBytes[code];
        default:
          return _charToUnicodeMoreBytes[code];
      }
    }

    String? unicode;
    if (code < 256) {
      unicode = toUnicode(code, 1);
    }
    if (unicode != null) {
      return unicode;
    }
    if (code <= 0xffff) {
      return toUnicode(code, 2);
    }
    if (code <= 0xffffff) {
      return toUnicode(code, 3);
    }
    return toUnicode(code, 4);
  }

  String? toUnicodeBytes(Uint8List code) {
    return toUnicode(toInt(code), code.length);
  }

  int readCode(RandomAccessRead input) {
    if (_maxCodeLength == 0) {
      // fallback to single byte reads when no codespace info is present
      final value = input.read();
      return value == -1 ? -1 : value & 0xff;
    }

    final startPosition = input.position;
    final buffer = Uint8List(_maxCodeLength);
    final read = input.readBuffer(buffer, 0, _minCodeLength);
    if (read < _minCodeLength) {
      // EOF
      input.seek(startPosition + (read > 0 ? read : 0));
      return -1;
    }

    for (var i = _minCodeLength - 1; i < _maxCodeLength; i++) {
      final byteCount = i + 1;
      if (_codespaceRanges.any((range) => range.isFullMatch(buffer, byteCount))) {
        return toInt(buffer, byteCount);
      }
      if (byteCount < _maxCodeLength) {
        final next = input.read();
        if (next == -1) {
          break;
        }
        buffer[byteCount] = next & 0xff;
      }
    }

    // invalid sequence, restore position to after the initial mandatory bytes
    input.seek(startPosition + _minCodeLength);
    return toInt(buffer, _minCodeLength);
  }

  int toCID(Uint8List code) {
    if (!hasCIDMappings() || code.length < _minCidLength || code.length > _maxCidLength) {
      return 0;
    }
    final directMap = _codeToCid[code.length];
    final cid = directMap?[toInt(code)];
    if (cid != null) {
      return cid;
    }
    return _toCidFromRangesBytes(code);
  }

  int toCIDFromInt(int code) {
    if (!hasCIDMappings()) {
      return 0;
    }
    var cid = 0;
    var length = _minCidLength;
    while (cid == 0 && length <= _maxCidLength) {
      cid = toCIDWithLength(code, length);
      length++;
    }
    return cid;
  }

  int toCIDWithLength(int code, int length) {
    if (!hasCIDMappings() || length < _minCidLength || length > _maxCidLength) {
      return 0;
    }
    final direct = _codeToCid[length];
    final value = direct?[code];
    if (value != null) {
      return value;
    }
    return _toCidFromRanges(code, length);
  }

  void addCharMapping(Uint8List codes, String unicode) {
    switch (codes.length) {
      case 1:
        _charToUnicodeOneByte[CMapStrings.getIndexValue(codes)!] = unicode;
        _unicodeToByteCodes[unicode] =
            Uint8List.fromList(CMapStrings.getByteValue(codes)!);
        break;
      case 2:
        _charToUnicodeTwoBytes[CMapStrings.getIndexValue(codes)!] = unicode;
        _unicodeToByteCodes[unicode] =
            Uint8List.fromList(CMapStrings.getByteValue(codes)!);
        break;
      case 3:
      case 4:
  _charToUnicodeMoreBytes[toInt(codes)] = unicode;
  _unicodeToByteCodes[unicode] = Uint8List.fromList(codes);
        break;
      default:
        // mappings longer than 4 bytes are not supported in the original implementation either
        break;
    }
    if (unicode == _space) {
      _spaceMapping = toInt(codes);
    }
  }

  Uint8List? getCodesFromUnicode(String unicode) => _unicodeToByteCodes[unicode];

  void addCIDMapping(Uint8List code, int cid) {
    final mapping = _codeToCid.putIfAbsent(code.length, () => <int, int>{});
    mapping[toInt(code)] = cid;
    _minCidLength = _minCidLength < code.length ? _minCidLength : code.length;
    _maxCidLength = _maxCidLength > code.length ? _maxCidLength : code.length;
  }

  void addCIDRange(Uint8List from, Uint8List to, int cid) {
    _addCIDRange(_codeToCidRanges, toInt(from), toInt(to), cid, from.length);
  }

  void addCodespaceRange(CodespaceRange range) {
    _codespaceRanges.add(range);
    _maxCodeLength = _maxCodeLength > range.codeLength ? _maxCodeLength : range.codeLength;
    _minCodeLength = _minCodeLength < range.codeLength ? _minCodeLength : range.codeLength;
  }

  void useCmap(CMap other) {
    for (final range in other._codespaceRanges) {
      addCodespaceRange(range);
    }
    other._charToUnicodeOneByte.forEach((key, value) {
      _charToUnicodeOneByte[key] = value;
      _unicodeToByteCodes[value] = Uint8List.fromList(<int>[key & 0xff]);
    });
    other._charToUnicodeTwoBytes.forEach((key, value) {
      _charToUnicodeTwoBytes[key] = value;
      _unicodeToByteCodes[value] = Uint8List.fromList(<int>[
        (key >> 8) & 0xff,
        key & 0xff,
      ]);
    });
    other._charToUnicodeMoreBytes.forEach((key, value) {
      final length = key <= 0xffffff ? 3 : 4;
      final buffer = Uint8List(length);
      for (var i = length - 1; i >= 0; i--) {
        buffer[i] = (key >> (8 * (length - 1 - i))) & 0xff;
      }
      _charToUnicodeMoreBytes[key] = value;
      _unicodeToByteCodes[value] = buffer;
    });
    other._codeToCid.forEach((length, mapping) {
      final target = _codeToCid.putIfAbsent(length, () => <int, int>{});
      target.addAll(mapping);
      _minCidLength = _minCidLength < length ? _minCidLength : length;
      _maxCidLength = _maxCidLength > length ? _maxCidLength : length;
    });
    _codeToCidRanges.addAll(other._codeToCidRanges);
    _maxCodeLength = _maxCodeLength > other._maxCodeLength ? _maxCodeLength : other._maxCodeLength;
    _minCodeLength = _minCodeLength < other._minCodeLength ? _minCodeLength : other._minCodeLength;
    _maxCidLength = _maxCidLength > other._maxCidLength ? _maxCidLength : other._maxCidLength;
    _minCidLength = _minCidLength < other._minCidLength ? _minCidLength : other._minCidLength;
    if (other._spaceMapping != -1) {
      _spaceMapping = other._spaceMapping;
    }
  }

  int get wMode => _wMode;
  set wMode(int value) => _wMode = value;

  String? get name => _name;
  set name(String? value) => _name = value;

  String? get version => _version;
  set version(String? value) => _version = value;

  int get type => _type;
  set type(int value) => _type = value;

  String? get registry => _registry;
  set registry(String? value) => _registry = value;

  String? get ordering => _ordering;
  set ordering(String? value) => _ordering = value;

  int get supplement => _supplement;
  set supplement(int value) => _supplement = value;

  int get spaceMapping => _spaceMapping;

  @override
  String toString() => _name ?? super.toString();

  static int toInt(Uint8List data, [int? length]) {
    final effectiveLength = length ?? data.length;
    var code = 0;
    for (var i = 0; i < effectiveLength; i++) {
      code = (code << 8) | (data[i] & 0xff);
    }
    return code;
  }

  int _toCidFromRanges(int code, int length) {
    for (final range in _codeToCidRanges) {
      final mapped = range.mapCode(code, length);
      if (mapped != -1) {
        return mapped;
      }
    }
    return 0;
  }

  int _toCidFromRangesBytes(Uint8List code) {
    for (final range in _codeToCidRanges) {
      final mapped = range.mapBytes(code);
      if (mapped != -1) {
        return mapped;
      }
    }
    return 0;
  }

  void _addCIDRange(List<CidRange> ranges, int from, int to, int cid, int length) {
    final last = ranges.isEmpty ? null : ranges.last;
    if (last == null || !last.extend(from, to, cid, length)) {
      ranges.add(CidRange(from, to, cid, length));
      _minCidLength = _minCidLength < length ? _minCidLength : length;
      _maxCidLength = _maxCidLength > length ? _maxCidLength : length;
    }
  }
}
