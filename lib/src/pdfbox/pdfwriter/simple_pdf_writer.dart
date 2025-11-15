import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_boolean.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_float.dart';
import '../cos/cos_integer.dart';
import '../cos/cos_name.dart';
import '../cos/cos_null.dart';
import '../cos/cos_number.dart';
import '../cos/cos_object.dart';
import '../cos/cos_stream.dart';
import '../cos/cos_string.dart';
import '../filter/flate_filter.dart';
import '../pdmodel/pd_document.dart';
import 'pdf_save_options.dart';

/// Minimal PDF serializer that supports the current PDModel feature set.
class SimplePdfWriter {
  SimplePdfWriter(this.document, this.options);

  static const FlateFilter _flateFilter = FlateFilter();

  final PDDocument document;
  final PDFSaveOptions options;

  final Map<COSBase, _ObjectEntry> _objectNumbers =
      LinkedHashMap<COSBase, _ObjectEntry>.identity();
  final List<_ObjectEntry> _orderedObjects = <_ObjectEntry>[];

  Uint8List write() {
    final cosDocument = document.cosDocument;
    final rootBase = cosDocument.trailer.getDictionaryObject(COSName.root);
    if (rootBase is! COSDictionary) {
      throw StateError('COSDocument trailer missing /Root dictionary');
    }

    _collect(rootBase);
    final infoBase = cosDocument.trailer.getDictionaryObject(COSName.info);
    if (infoBase is COSDictionary) {
      _collect(infoBase);
    }
    final encryptEntry = cosDocument.trailer.getItem(COSName.encrypt);
    if (encryptEntry != null) {
      _collect(encryptEntry);
    }

    final builder = BytesBuilder(copy: false);
    void writeText(String value) => builder.add(latin1.encode(value));

    writeText('%PDF-1.7\n');
    if (options.includeBinaryHeader) {
      writeText('%âãÏÓ\n');
    }

    final offsets = List<int>.filled(_orderedObjects.length + 1, 0);

    for (final entry in _orderedObjects) {
      offsets[entry.number] = builder.length;
      writeText('${entry.number} 0 obj\n');
      _writeObject(entry.base, builder, writeText);
      writeText('\nendobj\n');
    }

    final startXref = builder.length;
    final objectCount = _orderedObjects.length + 1;

    writeText('xref\n');
    writeText('0 $objectCount\n');
    writeText('0000000000 65535 f \n');
    for (var i = 1; i < objectCount; i++) {
      final offset = offsets[i];
      final offsetString = offset.toString().padLeft(10, '0');
      writeText('$offsetString 00000 n \n');
    }

    final rootRef = _referenceFor(rootBase);
    final infoRef = infoBase is COSDictionary ? _referenceFor(infoBase) : null;
    final encryptRef =
        encryptEntry != null ? _referenceFor(encryptEntry) : null;
    final prevOffset = options.previousStartXref ??
        _intFrom(cosDocument.trailer.getDictionaryObject(COSName.prev));
    final idArray = _resolveDocumentId(cosDocument.trailer);

    writeText('trailer\n<<\n');
    writeText('${COSName.size} $objectCount\n');
    writeText('${COSName.root} $rootRef\n');
    if (infoRef != null) {
      writeText('${COSName.info} $infoRef\n');
    }
    if (encryptRef != null) {
      writeText('${COSName.encrypt} $encryptRef\n');
    }
    if (prevOffset != null) {
      writeText('${COSName.prev} $prevOffset\n');
    }
    if (idArray != null && idArray.isNotEmpty) {
      final formatted = idArray.map(_formatHexString).join(' ');
      writeText('${COSName.id} [$formatted]\n');
    }
    writeText('>>\nstartxref\n$startXref\n%%EOF\n');

    return builder.toBytes();
  }

  void _collect(COSBase? base) {
    if (base == null) {
      return;
    }
    if (base is COSObject) {
      _collect(base.object);
      return;
    }
    if (base is COSStream) {
      if (_objectNumbers.containsKey(base)) {
        return;
      }
      _addObject(base);
      for (final entry in base.entries) {
        _collect(entry.value);
      }
      return;
    }
    if (base is COSDictionary) {
      if (_objectNumbers.containsKey(base)) {
        return;
      }
      _addObject(base);
      for (final entry in base.entries) {
        _collect(entry.value);
      }
      return;
    }
    if (base is COSArray) {
      for (final element in base) {
        _collect(element);
      }
    }
  }

  void _writeObject(
    COSBase base,
    BytesBuilder builder,
    void Function(String) writeText,
  ) {
    if (base is COSStream) {
      _writeStream(base, builder, writeText);
    } else if (base is COSDictionary) {
      _writeDictionary(base, builder, writeText);
    } else {
      throw StateError('Top-level objects must be dictionaries or streams');
    }
  }

  void _writeDictionary(
    COSDictionary dictionary,
    BytesBuilder builder,
    void Function(String) writeText,
  ) {
    writeText('<<');
    for (final entry in dictionary.entries) {
      writeText('\n${entry.key} ');
      _writeValue(entry.value, builder, writeText);
    }
    writeText('\n>>');
  }

  void _writeStream(
    COSStream stream,
    BytesBuilder builder,
    void Function(String) writeText,
  ) {
    final originalLength = stream.getItem(COSName.length);
    final serialization = _prepareStreamForWrite(stream);
    final data = serialization.data;
    stream.setInt(COSName.length, data.length);

    _writeDictionary(stream, builder, writeText);
    writeText('\nstream\n');
    if (data.isNotEmpty) {
      builder.add(data);
      if (data.last != 0x0a && data.last != 0x0d) {
        writeText('\n');
      }
    }
    writeText('endstream');

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

  void _writeValue(
    COSBase? value,
    BytesBuilder builder,
    void Function(String) writeText,
  ) {
    if (value == null || value is COSNull) {
      writeText('null');
      return;
    }
    if (value is COSBoolean) {
      writeText(value.value ? 'true' : 'false');
      return;
    }
    if (value is COSNumber) {
      writeText(_formatNumber(value));
      return;
    }
    if (value is COSName) {
      writeText(value.toString());
      return;
    }
    if (value is COSString) {
      if (value.isHex) {
        writeText(_formatHexStringLiteral(value));
      } else {
        writeText(_formatString(value));
      }
      return;
    }
    if (value is COSArray) {
      writeText('[');
      var first = true;
      for (final element in value) {
        if (!first) {
          writeText(' ');
        }
        _writeValue(element, builder, writeText);
        first = false;
      }
      writeText(']');
      return;
    }
    if (value is COSDictionary || value is COSStream) {
      writeText(_referenceFor(value));
      return;
    }
    if (value is COSObject) {
      final actual = value.object;
      if (actual is COSDictionary || actual is COSStream) {
        writeText(_referenceFor(actual));
      } else {
        _writeValue(actual, builder, writeText);
      }
      return;
    }
    throw StateError('Unsupported COS value ${value.runtimeType}');
  }

  _StreamSerialization _prepareStreamForWrite(COSStream stream) {
    final originalFilter = stream.getItem(COSName.filter);
    final data = stream.encodedBytes(copy: false) ?? Uint8List(0);

    if (!options.compressStreams || originalFilter != null || data.isEmpty) {
      return _StreamSerialization(data, originalFilter: originalFilter);
    }

    final compressed = _flateFilter.encode(data, COSDictionary(), 0);
    if (options.compressOnlyIfSmaller && compressed.length >= data.length) {
      return _StreamSerialization(data, originalFilter: originalFilter);
    }

    stream[COSName.filter] = COSName.flateDecode;
    return _StreamSerialization(
      Uint8List.fromList(compressed),
      originalFilter: originalFilter,
      filterAdded: true,
    );
  }

  String _formatNumber(COSNumber number) {
    if (number is COSInteger) {
      return number.intValue.toString();
    }
    if (number is COSFloat) {
      final doubleValue = number.doubleValue;
      if (doubleValue == doubleValue.truncateToDouble()) {
        return doubleValue.toInt().toString();
      }
      return doubleValue.toString();
    }
    return number.intValue.toString();
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
              ..write(_toOctal(byte));
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

  String _referenceFor(COSBase base) {
    final resolved = base is COSObject ? base.object : base;
    final entry = _objectNumbers[resolved];
    if (entry == null) {
      throw StateError('Missing object number for ${resolved.runtimeType}');
    }
    return '${entry.number} 0 R';
  }

  List<Uint8List>? _resolveDocumentId(COSDictionary trailer) {
    final override = options.overrideDocumentId;
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

    if (!options.generateDocumentId) {
      return null;
    }

    final seed = options.documentIdSeed ?? _defaultIdSeed();
    final digest = md5.convert(seed).bytes;
    final idBytes = Uint8List.fromList(digest);
    return <Uint8List>[idBytes, Uint8List.fromList(idBytes)];
  }

  Uint8List _defaultIdSeed() {
    final buffer = BytesBuilder(copy: false);
    final now = DateTime.now().toUtc();
    buffer.add(utf8.encode(now.toIso8601String()));
    buffer.addByte(document.numberOfPages);
    buffer.addByte(_objectNumbers.length);
    final random = Random();
    final randomData = ByteData(4)..setUint32(0, random.nextInt(0xffffffff));
    buffer.add(randomData.buffer.asUint8List());
    return buffer.toBytes();
  }

  int? _intFrom(COSBase? value) {
    if (value is COSInteger) {
      return value.intValue;
    }
    if (value is COSNumber) {
      return value.intValue;
    }
    return null;
  }

  String _formatHexString(Uint8List bytes) {
    final buffer = StringBuffer('<');
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    buffer.write('>');
    return buffer.toString().toUpperCase();
  }

  _ObjectEntry _addObject(COSBase base) {
    final entry = _ObjectEntry(_objectNumbers.length + 1, base);
    _objectNumbers[base] = entry;
    _orderedObjects.add(entry);
    return entry;
  }

  static String _toOctal(int value) => value.toRadixString(8).padLeft(3, '0');
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

class _ObjectEntry {
  _ObjectEntry(this.number, this.base);

  final int number;
  final COSBase base;
}
