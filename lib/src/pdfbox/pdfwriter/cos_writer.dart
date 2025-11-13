import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../io/random_access_write.dart';
import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_boolean.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_integer.dart';
import '../cos/cos_name.dart';
import '../cos/cos_null.dart';
import '../cos/cos_number.dart';
import '../cos/cos_object.dart';
import '../cos/cos_object_key.dart';
import '../cos/cos_stream.dart';
import '../cos/cos_string.dart';
import '../pdmodel/pd_document.dart';
import '../filter/flate_filter.dart';
import '../pdfparser/xref/free_x_reference.dart';
import '../pdfparser/xref/normal_x_reference.dart';
import '../pdfparser/xref/object_stream_x_reference.dart';
import '../pdfparser/xref/x_reference_entry.dart';
import '../pdfwriter/compress/compress_parameters.dart';
import '../pdfwriter/compress/cos_writer_compression_pool.dart';
import 'cos_standard_output_stream.dart';
import 'pdf_save_options.dart';

/// Serialises a [PDDocument] into PDF bytes, supporting optional object stream
/// compression as provided by PDFBox's COSWriter.
class COSWriter {
  COSWriter(this._target, this._options)
      : _output = COSStandardOutputStream(_target);

  static final Uint8List _pdfHeader = Uint8List.fromList('%PDF-1.7\n'.codeUnits);
  static final Uint8List _binaryHeader =
      Uint8List.fromList(latin1.encode('%\u00e2\u00e3\u00cf\u00d3\n'));
  static const FlateFilter _flateFilter = FlateFilter();

  final RandomAccessWrite _target;
  final PDFSaveOptions _options;
  final COSStandardOutputStream _output;

  final List<NormalXReference> _normalReferences = <NormalXReference>[];
  final List<ObjectStreamXReference> _objectStreamReferences =
      <ObjectStreamXReference>[];

  int _highestObjectNumber = 0;

  void writeDocument(PDDocument document) {
    _target.clear();
    _normalReferences.clear();
    _objectStreamReferences.clear();

    final cosDocument = document.cosDocument;
    final trailer = cosDocument.trailer;

    final Map<COSObjectKey, COSBase> documentObjects = <COSObjectKey, COSBase>{};
    for (final cosObject in cosDocument.objects) {
      final key = cosObject.key;
      if (key == null) {
        continue;
      }
      documentObjects[key] = cosObject.object;
      if (key.objectNumber > _highestObjectNumber) {
        _highestObjectNumber = key.objectNumber;
      }
    }

    final bool useObjectStreams =
        _options.objectStreamCompression?.isCompress ?? false;

    final Map<COSObjectKey, COSBase> indirectObjects =
        <COSObjectKey, COSBase>{};
    final Set<COSObjectKey> compressedKeys = <COSObjectKey>{};
    final List<_ObjectStreamInfo> objectStreams = <_ObjectStreamInfo>[];

    if (useObjectStreams) {
      _initialiseCompression(
        document,
        documentObjects,
        indirectObjects,
        objectStreams,
        compressedKeys,
      );
    } else {
      indirectObjects.addAll(documentObjects);
    }

    if (compressedKeys.isNotEmpty) {
      for (final key in compressedKeys) {
        indirectObjects.remove(key);
      }
    }

    _writeHeader();

    final objects = indirectObjects.entries
        .map((entry) => _IndirectObject(entry.key, entry.value))
        .toList()
      ..sort((a, b) => _compareKeys(a.key, b.key));

    for (final object in objects) {
      _writeIndirectObject(object);
    }

    final bool wroteObjectStreams = objectStreams.isNotEmpty;

    if (useObjectStreams && wroteObjectStreams) {
      cosDocument.isXRefStream = true;
      _writeCompressedXrefSection(trailer);
    } else {
      cosDocument.isXRefStream = false;
      _writeClassicXrefSection(document, trailer);
    }
  }

  void _initialiseCompression(
    PDDocument document,
    Map<COSObjectKey, COSBase> documentObjects,
    Map<COSObjectKey, COSBase> indirectObjects,
    List<_ObjectStreamInfo> objectStreams,
    Set<COSObjectKey> compressedKeys,
  ) {
    final CompressParameters parameters =
        _options.objectStreamCompression ?? const CompressParameters();
    final compressionPool = COSWriterCompressionPool(document, parameters);

    final topLevelKeys = compressionPool.getTopLevelObjects().toSet();
    final iterator = documentObjects.entries.iterator;
    while (iterator.moveNext()) {
      final entry = iterator.current;
      if (topLevelKeys.contains(entry.key)) {
        indirectObjects[entry.key] = entry.value;
      }
    }

    for (final key in compressionPool.getObjectStreamObjects()) {
      compressedKeys.add(key);
    }

    final objectStreamWriters = compressionPool.createObjectStreams();
    var nextObjectNumber = math.max(
      _highestObjectNumber,
      compressionPool.highestXRefObjectNumber,
    );

    for (final writer in objectStreamWriters) {
      if (writer.preparedKeys.isEmpty) {
        continue;
      }
      nextObjectNumber++;
      final streamKey = COSObjectKey(nextObjectNumber, 0);
      final stream = COSStream();
      stream.key = streamKey;
      writer.writeObjectsToStream(stream);
      objectStreams.add(_ObjectStreamInfo(streamKey, stream, writer.preparedKeys));
      indirectObjects[streamKey] = stream;
      _highestObjectNumber = math.max(_highestObjectNumber, nextObjectNumber);

      for (var index = 0; index < writer.preparedKeys.length; index++) {
        final key = writer.preparedKeys[index];
        final base = compressionPool.getObject(key) ?? documentObjects[key];
        if (base == null) {
          continue;
        }
        _objectStreamReferences
            .add(ObjectStreamXReference(index, key, base, streamKey));
      }
    }
  }

  void _writeHeader() {
    _output.writeBytes(_pdfHeader);
    if (_options.includeBinaryHeader) {
      _output.writeBytes(_binaryHeader);
    }
  }

  void _writeIndirectObject(_IndirectObject object) {
    final offset = _output.position;
    final key = object.key;
    final base = object.base;

    _normalReferences.add(NormalXReference(offset, key, base));

    _writeAscii('${key.objectNumber} ${key.generationNumber} obj\n');
    if (base is COSStream) {
      _writeStream(base);
    } else if (base is COSDictionary) {
      _writeDictionary(base);
      _output.writeLF();
    } else {
      _writeBase(base);
      _output.writeLF();
    }
    _writeAscii('endobj\n');
  }

  void _writeStream(COSStream stream) {
    final originalLength = stream.getItem(COSName.length);
    final serialization = _prepareStreamForWrite(stream);
    final data = serialization.data;
    stream.setInt(COSName.length, data.length);

    _writeDictionary(stream);
    _output.writeLF();
    _writeAscii('stream\n');
    if (data.isNotEmpty) {
      _output.writeBytes(data);
      final last = data.isNotEmpty ? data[data.length - 1] : 0;
      if (last != 0x0a && last != 0x0d) {
        _output.writeLF();
      }
    }
    _writeAscii('endstream\n');

    if (serialization.filterAdded) {
      if (serialization.originalFilter != null) {
        stream[COSName.filter] = serialization.originalFilter!;
      } else {
        stream.removeItem(COSName.filter);
      }
    }

    if (originalLength == null) {
      stream.removeItem(COSName.length);
    } else {
      stream[COSName.length] = originalLength;
    }
  }

  void _writeDictionary(COSDictionary dictionary) {
    _writeAscii('<<');
    for (final entry in dictionary.entries) {
      _output.writeLF();
      _writeAscii('${entry.key} ');
      _writeBase(entry.value);
    }
    _writeAscii('\n>>');
  }

  void _writeBase(COSBase? value) {
    if (value == null || value is COSNull) {
      _writeAscii('null');
      return;
    }
    if (value is COSBoolean) {
      _writeAscii(value.value ? 'true' : 'false');
      return;
    }
    if (value is COSNumber) {
      _writeAscii(_formatNumber(value));
      return;
    }
    if (value is COSName) {
      _writeAscii(value.toString());
      return;
    }
    if (value is COSString) {
      if (value.isHex) {
        _writeAscii(_formatHexStringLiteral(value));
      } else {
        _writeAscii(_formatString(value));
      }
      return;
    }
    if (value is COSArray) {
      _writeAscii('[');
      var first = true;
      for (final element in value) {
        if (!first) {
          _writeAscii(' ');
        }
        _writeBase(element);
        first = false;
      }
      _writeAscii(']');
      return;
    }
    if (value is COSStream) {
      // Inline streams are not expected; fallback to object reference when possible.
      final key = value.key;
      if (key != null) {
        _writeAscii('${key.objectNumber} ${key.generationNumber} R');
        return;
      }
      _writeStream(value);
      return;
    }
    if (value is COSDictionary) {
      _writeDictionary(value);
      return;
    }
    if (value is COSObject) {
      final key = value.key;
      if (key != null) {
        _writeAscii('${key.objectNumber} ${key.generationNumber} R');
        return;
      }
      _writeBase(value.object);
      return;
    }
    throw StateError('Unsupported COS value ${value.runtimeType}');
  }

  void _writeClassicXrefSection(PDDocument document, COSDictionary trailer) {
    final size = _calculateClassicSize();
    final startXref = _output.position;

    _writeAscii('xref\n');
    _writeAscii('0 $size\n');
    _writeAscii('0000000000 65535 f \n');

    final offsets = List<_ClassicXrefEntry?>.filled(size, null);
    for (final entry in _normalReferences) {
      final key = entry.referencedKey;
      if (key.objectNumber >= size) {
        continue;
      }
      offsets[key.objectNumber] =
          _ClassicXrefEntry(entry.secondColumnValue, entry.thirdColumnValue);
    }

    for (var i = 1; i < size; i++) {
      final record = offsets[i];
      if (record == null) {
        _writeAscii('0000000000 00000 f \n');
      } else {
        final offsetString = record.offset.toString().padLeft(10, '0');
        final generation = record.generation.toString().padLeft(5, '0');
        _writeAscii('$offsetString $generation n \n');
      }
    }

    final rootRef = _formatReference(trailer[COSName.root]);
    final infoRef = _formatReference(trailer[COSName.info]);
    final prevOffset =
  _options.previousStartXref ?? _intFrom(trailer.getDictionaryObject(COSName.prev));
    final idArray = _resolveDocumentId(trailer);

    _writeAscii('trailer\n<<\n');
    _writeAscii('${COSName.size} $size\n');
    if (rootRef != null) {
      _writeAscii('${COSName.root} $rootRef\n');
    }
    if (infoRef != null) {
      _writeAscii('${COSName.info} $infoRef\n');
    }
    if (prevOffset != null) {
      _writeAscii('${COSName.prev} $prevOffset\n');
    }
    if (idArray != null && idArray.isNotEmpty) {
      final formatted = idArray.map(_formatIdHexString).join(' ');
      _writeAscii('${COSName.id} [$formatted]\n');
    }
    _writeAscii('>>\nstartxref\n$startXref\n%%EOF\n');
  }

  void _writeCompressedXrefSection(COSDictionary trailer) {
    final xrefOffset = _output.position;
    final xrefKey = COSObjectKey(_highestObjectNumber + 1, 0);
  _highestObjectNumber = xrefKey.objectNumber;

    final entries = <XReferenceEntry>[FreeXReference.nullEntry]
      ..addAll(_normalReferences)
      ..addAll(_objectStreamReferences)
      ..add(NormalXReference(xrefOffset, xrefKey, COSNull.instance));

    entries.sort();

    final size = _calculateCompressedSize(entries);
    final wArray = _computeFieldWidths(entries);
    final indexArray = _computeIndexArray(entries);
    final data = _buildXrefStreamData(entries, wArray);

    final xrefStream = COSStream();
    xrefStream.key = xrefKey;
    xrefStream.setItem(COSName.type, COSName.get('XRef'));
    xrefStream.setInt(COSName.size, size);
    xrefStream.setItem(COSName.w, _toCOSIntegerArray(wArray));
    xrefStream.setItem(COSName.index, _toCOSIntegerArray(indexArray));

    final rootEntry = trailer[COSName.root];
    if (rootEntry != null) {
      xrefStream.setItem(COSName.root, rootEntry);
    }
    final infoEntry = trailer[COSName.info];
    if (infoEntry != null) {
      xrefStream.setItem(COSName.info, infoEntry);
    }
    final prevOffset =
  _options.previousStartXref ?? _intFrom(trailer.getDictionaryObject(COSName.prev));
    if (prevOffset != null) {
      xrefStream.setInt(COSName.prev, prevOffset);
    }

    final idArray = _resolveDocumentId(trailer);
    if (idArray != null && idArray.isNotEmpty) {
      final id = COSArray();
      for (final bytes in idArray) {
        id.addObject(COSString.fromBytes(bytes, isHex: true));
      }
      xrefStream[COSName.id] = id;
    }

    xrefStream.data = data;

    _writeIndirectObject(_IndirectObject(xrefKey, xrefStream));

    final startXref = xrefOffset;
    _writeAscii('startxref\n$startXref\n%%EOF\n');
  }

  Uint8List _buildXrefStreamData(List<XReferenceEntry> entries, List<int> widths) {
    final builder = BytesBuilder(copy: false);
    for (final entry in entries) {
      _writeNumber(builder, entry.firstColumnValue, widths[0]);
      _writeNumber(builder, entry.secondColumnValue, widths[1]);
      _writeNumber(builder, entry.thirdColumnValue, widths[2]);
    }
    return builder.toBytes();
  }

  void _writeNumber(BytesBuilder builder, int value, int width) {
    if (width <= 0) {
      return;
    }
    final buffer = Uint8List(width);
    var remaining = value;
    for (var i = width - 1; i >= 0; i--) {
      buffer[i] = remaining & 0xff;
      remaining >>= 8;
    }
    builder.add(buffer);
  }

  List<int> _computeFieldWidths(List<XReferenceEntry> entries) {
    var maxType = 0;
    var maxSecond = 0;
    var maxThird = 0;
    for (final entry in entries) {
      maxType = math.max(maxType, entry.firstColumnValue);
      maxSecond = math.max(maxSecond, entry.secondColumnValue);
      maxThird = math.max(maxThird, entry.thirdColumnValue);
    }
    return <int>[
      _bytesForValue(maxType),
      _bytesForValue(maxSecond),
      _bytesForValue(maxThird),
    ];
  }

  List<int> _computeIndexArray(List<XReferenceEntry> entries) {
    final result = <int>[];
    int? start;
    int? previous;
    var count = 0;

    for (final entry in entries) {
      final key = entry.referencedKey;
      if (key == null) {
        continue;
      }
      final number = key.objectNumber;
      if (start == null) {
        start = number;
        previous = number;
        count = 1;
        continue;
      }
      if (previous != null && number == previous + 1) {
        previous = number;
        count++;
        continue;
      }
      result
        ..add(start)
        ..add(count);
      start = number;
      previous = number;
      count = 1;
    }

    if (start != null) {
      result
        ..add(start)
        ..add(count);
    }

    return result;
  }

  int _calculateClassicSize() {
    var max = 0;
    for (final entry in _normalReferences) {
      final key = entry.referencedKey;
      max = math.max(max, key.objectNumber);
    }
    return max + 1;
  }

  int _calculateCompressedSize(List<XReferenceEntry> entries) {
    var max = 0;
    for (final entry in entries) {
      final key = entry.referencedKey;
      if (key == null) {
        continue;
      }
      max = math.max(max, key.objectNumber);
    }
    return max + 1;
  }

  COSArray _toCOSIntegerArray(List<int> values) {
    final array = COSArray();
    for (final value in values) {
      array.addObject(COSInteger(value));
    }
    return array;
  }

  int _bytesForValue(int value) {
    if (value <= 0) {
      return 1;
    }
    var bytes = 0;
    var current = value;
    while (current > 0) {
      current >>= 8;
      bytes++;
    }
    return math.max(bytes, 1);
  }

  String? _formatReference(COSBase? base) {
    if (base is COSObject) {
      final key = base.key;
      if (key != null) {
        return '${key.objectNumber} ${key.generationNumber} R';
      }
    }
    if (base is COSDictionary) {
      final key = base.key;
      if (key != null) {
        return '${key.objectNumber} ${key.generationNumber} R';
      }
    } else if (base is COSStream) {
      final key = base.key;
      if (key != null) {
        return '${key.objectNumber} ${key.generationNumber} R';
      }
    }
    return null;
  }

  int? _intFrom(COSBase? base) {
    if (base is COSNumber) {
      return base.intValue;
    }
    return null;
  }

  List<Uint8List>? _resolveDocumentId(COSDictionary trailer) {
    final override = _options.overrideDocumentId;
    if (override != null && override.isNotEmpty) {
      if (override.length == 1) {
        final value = Uint8List.fromList(override.first);
        return <Uint8List>[value, Uint8List.fromList(value)];
      }
      return override
          .map((bytes) => Uint8List.fromList(bytes))
          .toList(growable: false);
    }

    final existing = trailer.getDictionaryObject(COSName.id);
    if (existing is COSArray && existing.isNotEmpty) {
      final ids = <Uint8List>[];
      for (final entry in existing) {
        if (entry is COSString) {
          ids.add(Uint8List.fromList(entry.bytes));
        }
      }
      if (ids.isNotEmpty) {
        if (ids.length == 1) {
          ids.add(Uint8List.fromList(ids.first));
        }
        return ids;
      }
    }

    if (!_options.generateDocumentId) {
      return null;
    }

    final seed =
        _options.documentIdSeed ?? _defaultIdSeed();
    final digest = md5.convert(seed).bytes;
    final idBytes = Uint8List.fromList(digest);
    return <Uint8List>[idBytes, Uint8List.fromList(idBytes)];
  }

  Uint8List _defaultIdSeed() {
    final buffer = BytesBuilder(copy: false);
    final now = DateTime.now().toUtc();
    buffer.add(utf8.encode(now.toIso8601String()));
  buffer.addByte(_normalReferences.length & 0xff);
  buffer.addByte(_objectStreamReferences.length & 0xff);
    final random = math.Random();
    final randomData = ByteData(4)..setUint32(0, random.nextInt(0xffffffff));
    buffer.add(randomData.buffer.asUint8List());
    return buffer.toBytes();
  }

  String _formatIdHexString(Uint8List bytes) {
    final buffer = StringBuffer('<');
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    buffer.write('>');
    return buffer.toString().toUpperCase();
  }

  String _formatNumber(COSNumber number) {
    if (number is COSInteger) {
      return number.intValue.toString();
    }
    final double value = number.doubleValue;
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  String _formatString(COSString string) {
    final buffer = StringBuffer('(');
    final bytes = string.bytes;
    for (final byte in bytes) {
      switch (byte) {
        case 0x08:
          buffer.write('\\b');
          break;
        case 0x09:
          buffer.write('\\t');
          break;
        case 0x0a:
          buffer.write('\\n');
          break;
        case 0x0c:
          buffer.write('\\f');
          break;
        case 0x0d:
          buffer.write('\\r');
          break;
        case 0x28:
          buffer.write('\\(');
          break;
        case 0x29:
          buffer.write('\\)');
          break;
        case 0x5c:
          buffer.write('\\\\');
          break;
        default:
          if (byte < 0x20 || byte > 0x7e) {
            buffer
              ..write('\\')
              ..write(byte.toRadixString(8).padLeft(3, '0'));
          } else {
            buffer.writeCharCode(byte);
          }
      }
    }
    buffer.write(')');
    return buffer.toString();
  }

  String _formatHexStringLiteral(COSString string) {
    final bytes = string.bytes;
    final buffer = StringBuffer('<');
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    buffer.write('>');
    return buffer.toString().toUpperCase();
  }

  void _writeAscii(String value) {
    if (value.isEmpty) {
      return;
    }
    _output.writeBytes(Uint8List.fromList(latin1.encode(value)));
  }

  int _compareKeys(COSObjectKey a, COSObjectKey b) {
    final objectComparison = a.objectNumber.compareTo(b.objectNumber);
    if (objectComparison != 0) {
      return objectComparison;
    }
    return a.generationNumber.compareTo(b.generationNumber);
  }

  _StreamSerialization _prepareStreamForWrite(COSStream stream) {
    final originalFilter = stream.getItem(COSName.filter);
    final data = stream.encodedBytes(copy: false) ?? Uint8List(0);

    if (!_options.compressStreams ||
        originalFilter != null ||
        data.isEmpty) {
      return _StreamSerialization(data, originalFilter: originalFilter);
    }

    final compressed =
        _flateFilter.encode(data, COSDictionary(), 0);
    if (_options.compressOnlyIfSmaller && compressed.length >= data.length) {
      return _StreamSerialization(data, originalFilter: originalFilter);
    }

    stream[COSName.filter] = COSName.flateDecode;
    return _StreamSerialization(
      compressed,
      originalFilter: originalFilter,
      filterAdded: true,
    );
  }
}

class _IndirectObject {
  _IndirectObject(this.key, this.base);

  final COSObjectKey key;
  final COSBase base;
}

class _ObjectStreamInfo {
  _ObjectStreamInfo(this.key, this.stream, this.objectKeys);

  final COSObjectKey key;
  final COSStream stream;
  final List<COSObjectKey> objectKeys;
}

class _ClassicXrefEntry {
  _ClassicXrefEntry(this.offset, this.generation);

  final int offset;
  final int generation;
}

class _StreamSerialization {
  const _StreamSerialization(
    this.data, {
    this.originalFilter,
    this.filterAdded = false,
  });

  final Uint8List data;
  final COSBase? originalFilter;
  final bool filterAdded;
}
