import 'dart:collection';

import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import '../../io/random_access_read.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_document.dart';
import '../cos/cos_name.dart';
import '../cos/cos_object_key.dart';
import '../cos/cos_stream.dart';
import 'base_parser.dart';
import 'cos_parser.dart';
import 'pdf_xref_stream_parser.dart';
import 'xref_trailer_resolver.dart';

class XrefParser {
  XrefParser(this.parser)
      : source = parser.source,
        _logger = Logger('pdfbox.XrefParser');

  static const int _xChar = 0x78; // 'x'
  static const List<int> _xrefTableToken = <int>[
    0x78,
    0x72,
    0x65,
    0x66
  ]; // xref
  static const List<int> _startXrefToken = <int>[
    0x73,
    0x74,
    0x61,
    0x72,
    0x74,
    0x78,
    0x72,
    0x65,
    0x66,
  ];
  static const int _minimumSearchOffset = 6;

  final COSParser parser;
  final RandomAccessRead source;
  final Logger _logger;
  final XrefTrailerResolver xrefTrailerResolver = XrefTrailerResolver();

  Map<COSObjectKey, int>? get xrefTable => xrefTrailerResolver.xrefTable;

  COSDictionary parseXref(COSDocument document, int startXRefOffset) {
    source.seek(startXRefOffset);
    var startXrefOffset = parseStartXref();
    if (startXrefOffset < 0) {
      startXrefOffset = startXRefOffset;
    }
    final fixedOffset = checkXRefOffset(startXrefOffset);
    if (fixedOffset > -1) {
      startXrefOffset = fixedOffset;
    }
    document.startXref = startXrefOffset;

    var prev = startXrefOffset;
    COSDictionary? trailer;
    final visitedOffsets = <int>{};

    while (prev > 0) {
      visitedOffsets.add(prev);
      source.seek(prev);
      parser.skipSpaces();
      visitedOffsets.add(source.position);

      if (source.peek() == _xChar) {
        final parsed = parseXrefTable(prev);
        if (!parsed) {
          prev = -1;
          break;
        }
        if (!parseTrailer()) {
          throw IOException(
              'Expected trailer after xref table at offset $prev');
        }
        trailer = xrefTrailerResolver.currentTrailer;
        if (trailer == null) {
          throw IOException('Missing trailer after xref table');
        }
        final nextPrev = trailer.getInt(COSName.prev);
        prev = nextPrev ?? -1;
      } else {
        prev = parseXrefObjStream(prev, true) ?? -1;
        trailer = xrefTrailerResolver.currentTrailer;
      }

      if (prev > 0) {
        final fixedPrev = checkXRefOffset(prev);
        if (fixedPrev > -1 && fixedPrev != prev) {
          prev = fixedPrev;
          trailer?.setInt(COSName.prev, prev);
        }
      }

      if (visitedOffsets.contains(prev)) {
        throw IOException('/Prev loop at offset $prev');
      }
    }

    xrefTrailerResolver.setStartxref(startXrefOffset);
    trailer = xrefTrailerResolver.trailer;
    if (trailer == null) {
      throw IOException('Unable to resolve trailer');
    }
    document.setTrailer(trailer);
    document.isXRefStream = xrefTrailerResolver.xrefType == XRefType.stream;
    checkXrefOffsets();

    final resolvedTable = xrefTrailerResolver.xrefTable;
    if (resolvedTable != null) {
      document.addXRefTable(resolvedTable);
    }
    final keys = document.xrefTable.keys;
    var maxObject = 0;
    for (final key in keys) {
      if (key.objectNumber > maxObject) {
        maxObject = key.objectNumber;
      }
    }
    document.highestXRefObjectNumber = maxObject;
    return trailer;
  }

  int parseStartXref() {
    var startXref = -1;
    if (parser.isString(_startXrefToken)) {
      parser.readString();
      parser.skipSpaces();
      startXref = parser.readLong();
    }
    return startXref;
  }

  bool parseTrailer() {
    final trailerOffset = source.position;
    var nextCharacter = source.peek();
    while (nextCharacter != 0x74 && BaseParser.isDigit(nextCharacter)) {
      if (source.position == trailerOffset) {
        _logger.warning(
            'Expected trailer object at offset $trailerOffset, keep trying');
      }
      parser.readLine();
      nextCharacter = source.peek();
    }
    if (source.peek() != 0x74) {
      return false;
    }
    final currentOffset = source.position;
    final nextLine = parser.readLine();
    if (nextLine.trim() != 'trailer') {
      if (nextLine.startsWith('trailer')) {
        source.seek(currentOffset + 'trailer'.length);
      } else {
        return false;
      }
    }
    parser.skipSpaces();
    final parsedTrailer = parser.parseCOSDictionary(true);
    xrefTrailerResolver.setTrailer(parsedTrailer);
    parser.skipSpaces();
    return true;
  }

  bool parseXrefTable(int startByteOffset) {
    if (source.peek() != _xChar) {
      return false;
    }
    final keyword = parser.readString();
    if (keyword.trim() != 'xref') {
      return false;
    }

    final lookahead = parser.readString();
    final lookaheadBytes = lookahead.codeUnits;
    source.seek(source.position - lookaheadBytes.length);

    xrefTrailerResolver.nextXrefObj(startByteOffset, XRefType.table);

    if (lookahead.startsWith('trailer')) {
      _logger.warning('Skipping empty xref table');
      return false;
    }

    while (true) {
      final currentLine = parser.readLine();
      final split = currentLine.split(RegExp(r'\s+'))
        ..removeWhere((value) => value.isEmpty);
      if (split.length != 2) {
        _logger.warning('Unexpected XRefTable Entry: $currentLine');
        return false;
      }
      final startId = int.tryParse(split[0]);
      final count = int.tryParse(split[1]);
      if (startId == null || count == null) {
        _logger.warning('Invalid xref subsection header: $currentLine');
        return false;
      }

      parser.skipSpaces();
      var currentId = startId;
      for (var i = 0; i < count; i++) {
        if (parser.isEOF) {
          break;
        }
        final nextChar = source.peek();
        if (nextChar == 0x74 || BaseParser.isEndOfName(nextChar)) {
          break;
        }
        final line = parser.readLine();
        final parts = line.split(RegExp(r'\s+'))
          ..removeWhere((value) => value.isEmpty);
        if (parts.length < 3) {
          _logger.warning('Invalid xref line: $line');
          break;
        }
        if (parts.last == 'n') {
          final currOffset = int.tryParse(parts[0]);
          final currGen = int.tryParse(parts[1]);
          if (currOffset != null && currOffset > 0 && currGen != null) {
            xrefTrailerResolver.setXRef(
                COSObjectKey(currentId, currGen), currOffset);
          }
        } else if (parts[2] != 'f') {
          throw IOException('Corrupt XRefTable Entry - ObjID:$currentId');
        }
        currentId++;
        parser.skipSpaces();
      }
      parser.skipSpaces();
      if (!parser.isDigit()) {
        break;
      }
    }
    return true;
  }

  int? parseXrefObjStream(int objByteOffset, bool isStandalone) {
    parser.readObjectNumber();
    parser.readGenerationNumber();
    parser.readObjectMarker();

    final dictionary = parser.parseCOSDictionary(false);
    final COSStream xrefStream = parser.parseCOSStream(dictionary);

    if (isStandalone) {
      xrefTrailerResolver.nextXrefObj(objByteOffset, XRefType.stream);
      xrefTrailerResolver.setTrailer(xrefStream);
    }

    PDFXrefStreamParser(xrefStream).parse(xrefTrailerResolver);
    return dictionary.getInt(COSName.prev);
  }

  int checkXRefOffset(int startXRefOffset) {
    source.seek(startXRefOffset);
    parser.skipSpaces();
    if (parser.isString(_xrefTableToken)) {
      return startXRefOffset;
    }
    if (startXRefOffset > 0) {
      if (checkXRefStreamOffset(startXRefOffset)) {
        return startXRefOffset;
      }
      return calculateXRefFixedOffset(startXRefOffset);
    }
    return -1;
  }

  int calculateXRefFixedOffset(int objectOffset) {
    if (objectOffset < 0) {
      _logger.severe(
          'Invalid object offset $objectOffset when searching for a xref table/stream');
      return 0;
    }
    final newOffset = parser.bruteForceParser.bfSearchForXRef(objectOffset);
    if (newOffset > -1) {
      _logger.fine(
          'Fixed reference for xref table/stream $objectOffset -> $newOffset');
      return newOffset;
    }
    _logger.severe(
        "Can't find the object xref table/stream at offset $objectOffset");
    return 0;
  }

  bool checkXRefStreamOffset(int startXRefOffset) {
    if (startXRefOffset == 0) {
      return true;
    }
    source.seek(startXRefOffset - 1);
    final nextValue = source.read();
    if (BaseParser.isWhitespace(nextValue)) {
      parser.skipSpaces();
      if (parser.isDigit()) {
        try {
          parser.readObjectNumber();
          parser.readGenerationNumber();
          parser.readObjectMarker();
          final dict = parser.parseCOSDictionary(false);
          source.seek(startXRefOffset);
          if (dict.getNameAsString(COSName.type) == 'XRef') {
            return true;
          }
        } on IOException catch (exception) {
          _logger.fine(
              'No Xref stream at given location $startXRefOffset', exception);
          source.seek(startXRefOffset);
        }
      }
    }
    return false;
  }

  void checkXrefOffsets() {
    final xrefOffset = xrefTrailerResolver.xrefTable;
    if (xrefOffset == null) {
      return;
    }
    if (xrefOffset.isEmpty || !validateXrefOffsets(xrefOffset)) {
      final bruteForceParser = parser.bruteForceParser;
      final bruteForceOffsets = bruteForceParser.getBFCOSObjectOffsets();
      if (bruteForceOffsets.isNotEmpty) {
        _logger.fine(
            'Replaced read xref table with the results of a brute force search');
        xrefOffset
          ..clear()
          ..addAll(bruteForceOffsets);
        bruteForceParser.bfSearchForObjStreams(xrefOffset);
      }
    }
  }

  bool validateXrefOffsets(Map<COSObjectKey, int> xrefOffset) {
    final correctedKeys = HashMap<COSObjectKey, COSObjectKey>();
    final validKeys = <COSObjectKey>{};

    for (final entry in xrefOffset.entries) {
      final objectKey = entry.key;
      final objectOffset = entry.value;
      if (objectOffset < 0) {
        continue;
      }
      final found = findObjectKey(objectKey, objectOffset, xrefOffset);
      if (found == null) {
        _logger.fine(
          "Stop checking xref offsets as at least one ($objectKey) couldn't be dereferenced",
        );
        return false;
      }
      if (found != objectKey) {
        correctedKeys[objectKey] = found;
      } else {
        validKeys.add(objectKey);
      }
    }

    final correctedPointers = <COSObjectKey, int>{};
    correctedKeys.forEach((original, corrected) {
      if (!validKeys.contains(corrected)) {
        correctedPointers[corrected] = xrefOffset[original]!;
      }
    });

    for (final key in correctedKeys.keys) {
      xrefOffset.remove(key);
    }
    xrefOffset.addAll(correctedPointers);
    return true;
  }

  COSObjectKey? findObjectKey(
    COSObjectKey objectKey,
    int offset,
    Map<COSObjectKey, int> xrefOffset,
  ) {
    if (offset < _minimumSearchOffset) {
      return null;
    }
    try {
      source.seek(offset);
      parser.skipWhiteSpaces();
      if (source.position == offset) {
        source.seek(offset - 1);
        if (source.position < offset) {
          if (!parser.isDigit()) {
            source.read();
          } else {
            var current = source.position;
            source.seek(--current);
            while (parser.isDigit()) {
              source.seek(--current);
            }
            final newObjNumber = parser.readObjectNumber();
            final newGenNumber = parser.readGenerationNumber();
            final newKey = COSObjectKey(newObjNumber, newGenNumber);
            final existing = xrefOffset[newKey];
            if (existing != null &&
                existing > 0 &&
                (offset - existing).abs() < 10) {
              _logger.fine(
                  'Found the object $newKey instead of $objectKey at offset $offset - ignoring');
              return null;
            }
            source.seek(offset);
          }
        }
      }
      final foundNumber = parser.readObjectNumber();
      if (objectKey.objectNumber != foundNumber) {
        _logger.warning(
            'Found wrong object number. expected [${objectKey.objectNumber}] found [$foundNumber]');
        objectKey = COSObjectKey(foundNumber, objectKey.generationNumber);
      }
      final generationNumber = parser.readGenerationNumber();
      parser.readObjectMarker();
      if (generationNumber == objectKey.generationNumber) {
        return objectKey;
      } else if (generationNumber > objectKey.generationNumber) {
        return COSObjectKey(objectKey.objectNumber, generationNumber);
      }
    } on IOException catch (exception) {
      _logger.fine(
          'No valid object at given location $offset - ignoring', exception);
    }
    return null;
  }
}
