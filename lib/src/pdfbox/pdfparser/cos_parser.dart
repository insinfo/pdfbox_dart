import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../io/exceptions.dart';
import '../../io/random_access_read.dart';
import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_boolean.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_document.dart';
import '../cos/cos_float.dart';
import '../cos/cos_integer.dart';
import '../cos/cos_name.dart';
import '../cos/cos_null.dart';
import '../cos/cos_object.dart';
import '../cos/cos_object_key.dart';
import '../cos/cos_stream.dart';
import '../cos/cos_string.dart';
import '../filter/decode_options.dart';
import 'base_parser.dart';
import 'parsed_stream.dart';

/// Incremental Dart port of PDFBox's COSParser focused on object/xref handling.
///
/// Supports direct object parsing (scalars, arrays, dictionaries, streams),
/// indirect object hydration, stream decoding, classical xref tables with
/// trailer merging, and document loading into a [COSDocument].
class COSParser extends BaseParser {
  COSParser(RandomAccessRead source) : super(source);

  static const int _slash = 0x2f;
  static const int _leftBracket = 0x5b;
  static const int _rightBracket = 0x5d;
  static const int _lessThan = 0x3c;
  static const int _greaterThan = 0x3e;
  static const int _leftParen = 0x28;
  static const int _hash = 0x23;

  static final List<int> _endstreamPattern = 'endstream'.codeUnits;

  /// Parses the next direct object from the source, returning `null` when EOF is reached.
  COSBase? parseObject() {
    skipSpaces();
    final c = source.peek();
    if (c == -1) {
      return null;
    }

    switch (c) {
      case _leftParen:
        return COSString.fromBytes(readLiteralString());
      case _slash:
        return COSName.get(_readName());
      case _leftBracket:
        source.read();
        return _parseArray();
      case _lessThan:
        source.read();
        final next = source.peek();
        if (next == _lessThan) {
          source.read();
          final dict = _parseDictionary();
          return _maybeParseStream(dict);
        }
        return _parseHexString();
      default:
        break;
    }

    if (_isNumberStart(c)) {
      final token = readToken();
      if (token.isEmpty) {
        return null;
      }
      final reference = _maybeParseIndirectReference(token);
      if (reference != null) {
        return reference;
      }
      return _tokenToNumber(token);
    }

    final token = readToken();
    if (token.isEmpty) {
      return null;
    }
    switch (token) {
      case 'true':
        return COSBoolean.trueValue;
      case 'false':
        return COSBoolean.falseValue;
      case 'null':
        return COSNull.instance;
      default:
        return COSName.get(token);
    }
  }

  ParsedStream readStream(
    COSStream stream, {
    bool decode = true,
    DecodeOptions options = DecodeOptions.defaultOptions,
    bool retainEncodedCopy = true,
  }) {
    return resolveStream(
      stream,
      decode: decode,
      options: options,
      retainEncodedCopy: retainEncodedCopy,
    );
  }

  /// Parses the next indirect object in the source, returning `null` at EOF.
  /// When [document] is provided the parsed object is stored in the document pool.
  COSObject? parseIndirectObject({COSDocument? document}) {
    skipSpaces();
    final objectNumber = readLong();
    if (objectNumber == -1) {
      return null;
    }

    skipSpaces();
    final generationNumber = readInt();
    if (generationNumber == -1) {
      throw IOException('Malformed indirect object header: missing generation number');
    }

    final marker = readToken();
    if (marker != 'obj') {
      throw IOException("Expected 'obj' marker after object header but found '$marker'");
    }

    final value = parseObject() ?? COSNull.instance;
    value.isDirect = false;

    skipSpaces();
    final endMarker = readToken();
    if (endMarker != 'endobj') {
      throw IOException("Expected 'endobj' but found '$endMarker'");
    }

    final cosObject = COSObject(objectNumber, generationNumber, value);
    document?.addObject(cosObject);
    return cosObject;
  }

  /// Parses an indirect object located at [offset].
  COSObject? parseIndirectObjectAt(int offset, {COSDocument? document}) {
    source.seek(offset);
    return parseIndirectObject(document: document);
  }

  /// Parses an entire PDF file into a [COSDocument] using xref tables.
  COSDocument parseDocument() {
    final document = COSDocument();
    final startXref = _findStartXref();
    if (startXref == null) {
      throw IOException('Unable to locate startxref in source');
    }

    final Map<COSObjectKey, XrefEntry> objectEntries = <COSObjectKey, XrefEntry>{};
    final visitedXrefOffsets = <int>{};

    var currentOffset = startXref;
    while (currentOffset >= 0 && visitedXrefOffsets.add(currentOffset)) {
      source.seek(currentOffset);
      final info = parseXrefTrailer();

      if (document.trailer.isEmpty) {
        document.trailer.addAll(info.trailer);
      }

      for (final entry in info.entries.entries) {
        final objectNumber = entry.key;
        final xref = entry.value;

        if (!xref.inUse || xref.offset <= 0 || objectNumber == 0) {
          continue;
        }
        final key = COSObjectKey(objectNumber, xref.generation);
        objectEntries.putIfAbsent(key, () => xref);
      }

      final prevOffset = info.trailer.getInt(COSName.get('Prev'));
      if (prevOffset == null) {
        break;
      }
      currentOffset = prevOffset;
    }

    final sortedKeys = objectEntries.keys.toList()
      ..sort((a, b) {
        final cmp = a.objectNumber.compareTo(b.objectNumber);
        return cmp != 0
            ? cmp
            : a.generationNumber.compareTo(b.generationNumber);
      });

    for (final key in sortedKeys) {
      final entry = objectEntries[key]!;
      if (document.getObject(key) != null) {
        continue;
      }
      parseIndirectObjectAt(entry.offset, document: document);
    }

    return document;
  }

  COSArray _parseArray() {
    final array = COSArray();
    while (true) {
      skipSpaces();
      final next = source.peek();
      if (next == -1) {
        throw IOException('Unexpected EOF while parsing array');
      }
      if (next == _rightBracket) {
        source.read();
        break;
      }
      final value = parseObject();
      if (value == null) {
        throw IOException('Invalid array item encountered');
      }
      array.addObject(value);
    }
    return array;
  }

  COSDictionary _parseDictionary() {
    final dict = COSDictionary();
    while (true) {
      skipSpaces();
      final next = source.peek();
      if (next == -1) {
        throw IOException('Unexpected EOF while parsing dictionary');
      }
      if (next == _greaterThan) {
        source.read();
        final second = source.read();
        if (second != _greaterThan) {
          throw IOException('Expected >> to close dictionary');
        }
        break;
      }
      if (next != _slash) {
        // Leniently consume stray tokens before the closing marker.
        final skipped = readToken();
        if (skipped.isEmpty) {
          throw IOException('Malformed dictionary entry');
        }
        continue;
      }

      final key = COSName.get(_readName());
      final value = parseObject();
      if (value == null) {
        dict.setNull(key);
      } else {
        dict[key] = value;
      }
    }
    return dict;
  }

  COSString _parseHexString() {
    final buffer = StringBuffer();
    var c = source.read();
    while (c != -1 && c != _greaterThan) {
      if (!BaseParser.isWhitespace(c)) {
        buffer.writeCharCode(c);
      }
      c = source.read();
    }
    if (c != _greaterThan) {
      throw IOException('Missing closing > for hex string');
    }
    return COSString.fromHex(buffer.toString());
  }

  COSBase _maybeParseStream(COSDictionary dict) {
    final startPosition = source.position;
    skipSpaces();
    final keyword = readString();
    if (keyword != 'stream') {
      source.seek(startPosition);
      return dict;
    }

    final stream = COSStream()..addAll(dict);
    skipWhiteSpaces();

    final length = _resolveStreamLength(dict.getItem(COSName.length));
    final data = length != null ? _readStreamWithKnownLength(length) : _readStreamUntilEndstream();
    stream.data = data;

    final endMarker = readString();
    if (endMarker == 'endstream') {
      return stream;
    }
    if (endMarker == 'endobj') {
      source.rewind(endMarker.length);
      return stream;
    }
    throw IOException(
      "Expected 'endstream' but found '$endMarker' at offset ${source.position}",
    );
  }

  int? _resolveStreamLength(COSBase? lengthBase) {
    if (lengthBase == null) {
      return null;
    }
    if (lengthBase is COSInteger) {
      final value = lengthBase.intValue;
      return value >= 0 ? value : null;
    }
    if (lengthBase is COSFloat) {
      final value = lengthBase.intValue;
      return value >= 0 ? value : null;
    }
    if (lengthBase is COSObject) {
      return _resolveStreamLength(lengthBase.object);
    }
    return null;
  }

  Uint8List _readStreamWithKnownLength(int length) {
    if (length < 0) {
      throw IOException('Negative stream length');
    }
    final buffer = Uint8List(length);
    source.readFully(buffer);
    return buffer;
  }

  Uint8List _readStreamUntilEndstream() {
    final queue = ListQueue<int>();
    final data = <int>[];
    var lastByte = -1;

    while (true) {
      final byte = source.read();
      if (byte == -1) {
        throw IOException('Unexpected EOF while searching for endstream');
      }
      queue.addLast(byte);

      while (queue.length > _endstreamPattern.length) {
        final removed = queue.removeFirst();
        data.add(removed);
        lastByte = removed;
      }

      if (queue.length == _endstreamPattern.length) {
        if (_matchesPattern(queue, _endstreamPattern)) {
          final nextByte = source.peek();
          final precededByWhitespace =
              lastByte == -1 || BaseParser.isWhitespace(lastByte) || BaseParser.isEndOfName(lastByte);
          final followedByDelimiter =
              nextByte == -1 || BaseParser.isEndOfName(nextByte) || BaseParser.isWhitespace(nextByte);
          if (precededByWhitespace && followedByDelimiter) {
            source.rewind(_endstreamPattern.length);
            break;
          }
        }
        final removed = queue.removeFirst();
        data.add(removed);
        lastByte = removed;
      }
    }

    if (data.isNotEmpty) {
      if (data.last == 0x0a) {
        data.removeLast();
        if (data.isNotEmpty && data.last == 0x0d) {
          data.removeLast();
        }
      } else if (data.last == 0x0d) {
        data.removeLast();
      }
    }

    return Uint8List.fromList(data);
  }

  bool _matchesPattern(ListQueue<int> queue, List<int> pattern) {
    var index = 0;
    for (final value in queue) {
      if (value != pattern[index]) {
        return false;
      }
      index++;
    }
    return true;
  }

  int? _findStartXref({int searchLength = 2048}) {
    final fileLength = source.length;
    if (fileLength <= 0) {
      return null;
    }

    final originalPosition = source.position;
    final scanLength = math.min(searchLength, fileLength);
    final buffer = Uint8List(scanLength);

    source.seek(fileLength - scanLength);
    final read = source.readInto(buffer);
    final content = String.fromCharCodes(buffer.sublist(0, read));

    const marker = 'startxref';
    final markerIndex = content.lastIndexOf(marker);
    if (markerIndex < 0) {
      source.seek(originalPosition);
      return null;
    }

    final markerPosition = fileLength - scanLength + markerIndex;
    source.seek(markerPosition + marker.length);
    skipSpaces();
    final offsetToken = readToken();
    final offset = int.tryParse(offsetToken);

    source.seek(originalPosition);

    if (offset == null) {
      throw IOException('Invalid startxref value: $offsetToken');
    }
    return offset;
  }

  /// Parses a classic XRef table followed by trailer and startxref markers.
  XrefTrailerInfo parseXrefTrailer() {
    final keyword = readToken();
    if (keyword != 'xref') {
      throw IOException("Expected 'xref' keyword but found '$keyword'");
    }

    final entries = <int, XrefEntry>{};
    while (true) {
      skipSpaces();
      final peek = source.peek();
      if (peek == -1) {
        throw IOException('Unexpected EOF while reading xref table');
      }
      if (String.fromCharCode(peek) == 't') {
        final trailerKeyword = readToken();
        if (trailerKeyword != 'trailer') {
          throw IOException("Expected 'trailer' keyword but found '$trailerKeyword'");
        }
        break;
      }

      final startObjectNumber = readLong();
      if (startObjectNumber < 0) {
        throw IOException('Invalid xref subsection start object number');
      }
      skipSpaces();
      final entryCount = readLong();
      if (entryCount < 0) {
        throw IOException('Negative xref subsection length');
      }
      skipLinebreak();

      for (var i = 0; i < entryCount; i++) {
        final line = readLine();
        final parts = line
            .split(RegExp(r'\s+'))
            .where((element) => element.isNotEmpty)
            .toList();
        if (parts.length < 3) {
          throw IOException('Malformed xref entry line: "$line"');
        }
        final offset = int.tryParse(parts[0]);
        final generation = int.tryParse(parts[1]);
        final flag = parts[2];
        if (offset == null || generation == null) {
          throw IOException('Invalid offset or generation number in xref entry: "$line"');
        }
        entries[startObjectNumber + i] = XrefEntry(
          offset: offset,
          generation: generation,
          inUse: flag.startsWith('n'),
        );
      }
    }

    final trailerObject = parseObject();
    if (trailerObject is! COSDictionary) {
      throw IOException('Trailer must be a dictionary');
    }

    skipSpaces();
    final startXrefKeyword = readToken();
    if (startXrefKeyword != 'startxref') {
      throw IOException("Expected 'startxref' marker but found '$startXrefKeyword'");
    }
    skipSpaces();
    final offsetToken = readToken();
    final startXref = int.tryParse(offsetToken);
    if (startXref == null) {
      throw IOException('Invalid startxref offset: $offsetToken');
    }

    return XrefTrailerInfo(
      entries: entries,
      trailer: trailerObject,
      startXref: startXref,
    );
  }

  bool _isNumberStart(int c) {
    return c == 0x2b || c == 0x2d || c == 0x2e || (c >= 0x30 && c <= 0x39);
  }

  COSBase _tokenToNumber(String token) {
    if (token.contains('.') || token.contains('e') || token.contains('E')) {
      final value = double.tryParse(token);
      if (value == null) {
        throw IOException("Error: Expected a float value, got '$token'");
      }
      return COSFloat.valueOf(value);
    }
    final value = int.tryParse(token);
    if (value == null) {
      throw IOException("Error: Expected an integer value, got '$token'");
    }
    return COSInteger.valueOf(value);
  }

  COSBase? _maybeParseIndirectReference(String objectToken) {
    final objectNumber = int.tryParse(objectToken);
    if (objectNumber == null || objectNumber < 0) {
      return null;
    }

    final afterObjectToken = source.position;
    skipSpaces();

    final nextChar = source.peek();
    if (!_isNumberStart(nextChar)) {
      source.seek(afterObjectToken);
      return null;
    }

    final generationToken = readToken();
    final generationNumber = int.tryParse(generationToken);
    if (generationNumber == null || generationNumber < 0) {
      source.seek(afterObjectToken);
      return null;
    }

    skipSpaces();
    final rChar = source.peek();
    if (rChar != 0x52) {
      // 'R'
      source.seek(afterObjectToken);
      return null;
    }
    source.read();
    return COSObject(objectNumber, generationNumber);
  }

  String _readName() {
    final slash = source.read();
    if (slash != _slash) {
      throw IOException("Expected '/' starting a name");
    }
    final buffer = StringBuffer();
    var c = source.read();
    while (c != -1 && !BaseParser.isEndOfName(c)) {
      if (c == _hash) {
        final first = source.read();
        final second = source.read();
        if (first == -1 || second == -1) {
          if (second != -1) {
            source.rewind(1);
          }
          if (first != -1) {
            source.rewind(1);
          }
          buffer.writeCharCode(_hash);
        } else {
          final decoded = _decodeHexDigitPair(first, second);
          if (decoded == null) {
            source.rewind(1);
            source.rewind(1);
            buffer.writeCharCode(_hash);
          } else {
            buffer.writeCharCode(decoded);
          }
        }
      } else {
        buffer.writeCharCode(c);
      }
      c = source.read();
    }
    if (c != -1) {
      source.rewind(1);
    }
    return buffer.toString();
  }

  int? _decodeHexDigitPair(int high, int low) {
    final hi = _hexValue(high);
    final lo = _hexValue(low);
    if (hi == null || lo == null) {
      return null;
    }
    return (hi << 4) | lo;
  }

  int? _hexValue(int code) {
    if (code >= 0x30 && code <= 0x39) {
      return code - 0x30;
    }
    if (code >= 0x41 && code <= 0x46) {
      return code - 0x41 + 10;
    }
    if (code >= 0x61 && code <= 0x66) {
      return code - 0x61 + 10;
    }
    return null;
  }
}

class XrefEntry {
  const XrefEntry({required this.offset, required this.generation, required this.inUse});

  final int offset;
  final int generation;
  final bool inUse;
}

class XrefTrailerInfo {
  const XrefTrailerInfo({
    required this.entries,
    required this.trailer,
    required this.startXref,
  });

  final Map<int, XrefEntry> entries;
  final COSDictionary trailer;
  final int startXref;
}
