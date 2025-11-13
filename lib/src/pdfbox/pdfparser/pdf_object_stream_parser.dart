import '../../io/exceptions.dart';
import '../cos/cos_base.dart';
import '../cos/cos_document.dart';
import '../cos/cos_name.dart';
import '../cos/cos_object_key.dart';
import '../cos/cos_stream.dart';
import 'cos_parser.dart';

class ObjectStreamObject {
  ObjectStreamObject(this.key, this.object);

  final COSObjectKey key;
  final COSBase object;
}

class PDFObjectStreamParser extends COSParser {
  PDFObjectStreamParser(COSStream stream, COSDocument document)
      : _numberOfObjects = stream.getInt(COSName.n) ?? -1,
        _firstObject = stream.getInt(COSName.first) ?? -1,
        super(stream.createView(), document: document) {
    if (_numberOfObjects < 0) {
      throw IOException('/N entry missing in object stream');
    }
    if (_firstObject < 0) {
      throw IOException('/First entry missing in object stream');
    }
    this.document = document;
  }

  final int _numberOfObjects;
  final int _firstObject;

  List<ObjectStreamObject> parseAllObjects() {
    final results = <ObjectStreamObject>[];
    final headers = _readObjectHeaders();
    try {
      for (var index = 0; index < headers.length; index++) {
        final header = headers[index];
        final targetOffset = _firstObject + header.offset;
        if (targetOffset < 0) {
          continue;
        }
        source.seek(targetOffset);
        final parsed = parseObject();
        if (parsed == null) {
          continue;
        }
        parsed.isDirect = false;
        final key =
            COSObjectKey(header.objectNumber, header.generationNumber, index);
        results.add(ObjectStreamObject(key, parsed));
      }
      return results;
    } finally {
      source.close();
      document = null;
    }
  }

  Map<int, int> readObjectNumbers() {
    try {
      final headers = _readObjectHeaders();
      final objectNumbers = <int, int>{};
      for (final header in headers) {
        objectNumbers[header.objectNumber] = header.offset;
      }
      return objectNumbers;
    } finally {
      source.close();
      document = null;
    }
  }

  List<_StreamObjectHeader> _readObjectHeaders() {
    final headers = <_StreamObjectHeader>[];
    source.seek(0);
    final headerLimit = _firstObject;
    for (var i = 0; i < _numberOfObjects; i++) {
      if (headerLimit >= 0 && source.position >= headerLimit) {
        break;
      }
      final objectNumber = readObjectNumber();
      final offset = readLong();
      headers.add(_StreamObjectHeader(objectNumber, offset));
    }
    return headers;
  }
}

class _StreamObjectHeader {
  _StreamObjectHeader(this.objectNumber, this.offset);

  final int objectNumber;
  final int offset;
  final int generationNumber = 0;
}
