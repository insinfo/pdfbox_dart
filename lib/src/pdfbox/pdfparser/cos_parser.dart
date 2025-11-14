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
import 'brute_force_parser.dart';
import 'pdf_object_stream_parser.dart';
import 'xref_parser.dart';

/// Incremental Dart port of PDFBox's COSParser focused on object/xref handling.
///
/// Supports direct object parsing (scalars, arrays, dictionaries, streams),
/// indirect object hydration, stream decoding, classical xref tables with
/// trailer merging, and document loading into a [COSDocument].
class COSParser extends BaseParser {
  COSParser(RandomAccessRead source, {COSDocument? document})
      : _document = document,
        super(source);

  bool _lenient = true;
  bool _initialParseDone = false;

  bool get isLenient => _lenient;

  void setLenient(bool lenient) {
    if (_initialParseDone && lenient != _lenient) {
      throw ArgumentError('Cannot change leniency after parsing');
    }
    _lenient = lenient;
  }

  bool get initialParseDone => _initialParseDone;

  set initialParseDone(bool value) => _initialParseDone = value;

  static const int _slash = 0x2f;
  static const int _leftBracket = 0x5b;
  static const int _rightBracket = 0x5d;
  static const int _lessThan = 0x3c;
  static const int _greaterThan = 0x3e;
  static const int _leftParen = 0x28;
  static const int _hash = 0x23;

  static final List<int> _endstreamPattern = 'endstream'.codeUnits;

  BruteForceParser? _bruteForceParser;

  BruteForceParser get bruteForceParser {
    final cached = _bruteForceParser;
    if (cached != null) {
      return cached;
    }
    final currentDocument = _document;
    if (currentDocument == null) {
      throw StateError('BruteForceParser requested without an active document');
    }
    final parser = BruteForceParser(currentDocument, this);
    _bruteForceParser = parser;
    return parser;
  }

  COSDocument? _document;

  COSDocument? get document => _document;

  set document(COSDocument? value) {
    _document = value;
    if (value == null) {
      _bruteForceParser = null;
    }
  }
  
  /// Scans the source for [marker] and returns the detected version, falling back
  /// to [defaultVersion] when no explicit version is present. Returns `null`
  /// when the marker cannot be found within the first kilobyte, mirroring the
  /// behaviour of PDFBox's header detection.
  String? parseHeader(String marker, {required String defaultVersion}) {
    final originalPosition = source.position;
    try {
      source.seek(0);
      final scanLimit = math.min(source.length, 1024);
      if (scanLimit <= 0) {
        return null;
      }
      final buffer = Uint8List(scanLimit);
      final read = source.readInto(buffer);
      if (read <= 0) {
        return null;
      }
      final content = String.fromCharCodes(buffer.sublist(0, read));
      final index = content.indexOf(marker);
      if (index < 0) {
        return null;
      }
      final afterMarker = content.substring(index + marker.length);
      final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(afterMarker);
      return match?.group(1) ?? defaultVersion;
    } finally {
      source.seek(originalPosition);
    }
  }

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
      throw IOException(
          'Malformed indirect object header: missing generation number');
    }

    final marker = readToken();
    if (marker != 'obj') {
      throw IOException(
          "Expected 'obj' marker after object header but found '$marker'");
    }

    final value = parseObject() ?? COSNull.instance;
    value.isDirect = false;

    skipSpaces();
    final endMarker = readToken();
    if (endMarker != 'endobj') {
      throw IOException("Expected 'endobj' but found '$endMarker'");
    }

    COSObject cosObject;
    if (document != null) {
      final key = COSObjectKey(objectNumber, generationNumber);
      cosObject = document.getObjectFromPool(key);
      cosObject.object = value;
      document.addObject(cosObject);
    } else {
      cosObject = COSObject(objectNumber, generationNumber, value);
    }
    return cosObject;
  }

  /// Parses an indirect object located at [offset].
  COSObject? parseIndirectObjectAt(int offset, {COSDocument? document}) {
    source.seek(offset);
    return parseIndirectObject(document: document);
  }

  COSArray parseCOSArray() {
    skipSpaces();
    final marker = source.read();
    if (marker != _leftBracket) {
      final display = marker == -1 ? 'EOF' : String.fromCharCode(marker);
      throw IOException("Expected '[' to start array but found '$display'");
    }
    return _parseArray();
  }

  COSString parseCOSHexString() => _parseHexString();

  COSName parseCOSName() => COSName.get(_readName());

  String readName() => _readName();

  /// Parses an entire PDF file into a [COSDocument] using xref tables.
  COSDocument parseDocument() {
    final cosDocument = COSDocument();
    document = cosDocument;
    try {
      final startXref = _findStartXref();
      if (startXref == null) {
        throw IOException('Unable to locate startxref in source');
      }

      final xrefParser = XrefParser(this);
      final trailer = xrefParser.parseXref(cosDocument, startXref);
      if (cosDocument.trailer.isEmpty) {
        cosDocument.trailer.addAll(trailer);
      }

      final entries = cosDocument.xrefTable.entries
          .where((entry) => entry.value > 0 && entry.key.objectNumber != 0)
          .toList()
        ..sort((a, b) {
          final first = a.key;
          final second = b.key;
          final cmp = first.objectNumber.compareTo(second.objectNumber);
          if (cmp != 0) {
            return cmp;
          }
          return first.generationNumber.compareTo(second.generationNumber);
        });

      for (final entry in entries) {
        final key = entry.key;
        final existing = cosDocument.getObject(key);
        if (existing != null && !existing.isNull) {
          continue;
        }
        parseIndirectObjectAt(entry.value, document: cosDocument);
      }

      _parseCompressedObjects(cosDocument);
      cosDocument.markAllClean();
      return cosDocument;
    } finally {
      document = null;
    }
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
    final data = length != null
        ? _readStreamWithKnownLength(length)
        : _readStreamUntilEndstream();
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
          final precededByWhitespace = lastByte == -1 ||
              BaseParser.isWhitespace(lastByte) ||
              BaseParser.isEndOfName(lastByte);
          final followedByDelimiter = nextByte == -1 ||
              BaseParser.isEndOfName(nextByte) ||
              BaseParser.isWhitespace(nextByte);
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

  bool isDigit() {
    final next = source.peek();
    return next != -1 && BaseParser.isDigit(next);
  }

  bool isWhitespace() {
    final next = source.peek();
    return next != -1 && BaseParser.isWhitespace(next);
  }

  bool isString(List<int> pattern) {
    if (pattern.isEmpty) {
      return true;
    }
    final buffer = <int>[];
    for (final expected in pattern) {
      final value = source.read();
      if (value == -1) {
        if (buffer.isNotEmpty) {
          source.rewind(buffer.length);
        }
        return false;
      }
      buffer.add(value);
      if (value != expected) {
        source.rewind(buffer.length);
        return false;
      }
    }
    source.rewind(buffer.length);
    return true;
  }

  int readObjectNumber() {
    final value = readLong();
    if (value < 0) {
      throw IOException(
          'Expected positive object number at offset ${source.position}');
    }
    return value;
  }

  int readGenerationNumber() {
    final value = readInt();
    if (value < 0) {
      throw IOException(
          'Expected generation number at offset ${source.position}');
    }
    return value;
  }

  void readObjectMarker() {
    final marker = readToken();
    if (marker != 'obj') {
      throw IOException("Expected 'obj' marker but found '$marker'");
    }
  }

  COSDictionary parseCOSDictionary(bool isDirect) {
    skipSpaces();
    final first = source.read();
    final second = source.read();
    if (first != _lessThan || second != _lessThan) {
      final firstDesc = first == -1 ? 'EOF' : String.fromCharCode(first);
      final secondDesc = second == -1 ? 'EOF' : String.fromCharCode(second);
      throw IOException(
        "Expected '<<' to start dictionary but found '$firstDesc$secondDesc'",
      );
    }
    final dictionary = _parseDictionary();
    dictionary.isDirect = isDirect;
    return dictionary;
  }

  COSStream parseCOSStream(COSDictionary dictionary) {
    final base = _maybeParseStream(dictionary);
    if (base is COSStream) {
      return base;
    }
    throw IOException(
        'Expected stream following dictionary at offset ${source.position}');
  }

  void _parseCompressedObjects(COSDocument targetDocument) {
    final compressedEntries = targetDocument.xrefTable.entries
        .where((entry) => entry.value < 0)
        .toList();
    if (compressedEntries.isEmpty) {
      return;
    }

    final objectsByStream = <int, List<COSObjectKey>>{};
    for (final entry in compressedEntries) {
      final streamNumber = -entry.value;
      objectsByStream
          .putIfAbsent(streamNumber, () => <COSObjectKey>[])
          .add(entry.key);
    }

    for (final streamEntry in objectsByStream.entries) {
      final expectedKeys = List<COSObjectKey>.from(streamEntry.value);
      final streamObject = _findObjectStream(targetDocument, streamEntry.key);
      if (streamObject == null) {
        continue;
      }
      final stream = streamObject.object;
      if (stream is! COSStream) {
        continue;
      }

      final parser = PDFObjectStreamParser(stream, targetDocument);
      late final List<ObjectStreamObject> parsedObjects;
      try {
        parsedObjects = parser.parseAllObjects();
      } on IOException {
        continue;
      }

      for (final parsed in parsedObjects) {
        final matchedKey = _matchCompressedKey(parsed.key, expectedKeys);
        if (matchedKey == null) {
          continue;
        }
        expectedKeys.remove(matchedKey);

        final cosObject = targetDocument.getObject(parsed.key);
        if (cosObject != null) {
          cosObject.object = parsed.object;
        } else {
          targetDocument.addObject(
            COSObject(parsed.key.objectNumber, parsed.key.generationNumber,
                parsed.object),
          );
        }
      }
    }
  }

  COSObject? _findObjectStream(COSDocument targetDocument, int objectNumber) {
    final direct = targetDocument.getObjectByNumber(objectNumber);
    if (direct != null) {
      return direct;
    }
    for (final obj in targetDocument.objects) {
      if (obj.objectNumber == objectNumber) {
        return obj;
      }
    }
    return null;
  }

  COSObjectKey? _matchCompressedKey(
    COSObjectKey parsedKey,
    List<COSObjectKey> expectedKeys,
  ) {
    for (final key in expectedKeys) {
      if (key.objectNumber != parsedKey.objectNumber) {
        continue;
      }
      if (key.streamIndex != -1 && key.streamIndex != parsedKey.streamIndex) {
        continue;
      }
      return key;
    }
    return null;
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
          throw IOException(
              "Expected 'trailer' keyword but found '$trailerKeyword'");
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
          throw IOException(
              'Invalid offset or generation number in xref entry: "$line"');
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
      throw IOException(
          "Expected 'startxref' marker but found '$startXrefKeyword'");
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
    final key = COSObjectKey(objectNumber, generationNumber);
    final currentDocument = _document;
    if (currentDocument != null) {
      return currentDocument.getObjectFromPool(key);
    }
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
  const XrefEntry(
      {required this.offset, required this.generation, required this.inUse});

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
