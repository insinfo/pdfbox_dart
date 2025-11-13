import 'dart:convert';
import 'dart:typed_data';

import '../../../io/exceptions.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
import '../../cos/cos_boolean.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_integer.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_null.dart';
import '../../cos/cos_object.dart';
import '../../cos/cos_object_key.dart';
import '../../cos/cos_stream.dart';
import '../../cos/cos_string.dart';
import '../../filter/flate_filter.dart';
import 'cos_writer_compression_pool.dart';

/// Represents a compressed object stream in the writer.
class COSWriterObjectStream {
  COSWriterObjectStream(this._compressionPool);

  static const FlateFilter _flate = FlateFilter();

  final COSWriterCompressionPool _compressionPool;
  final List<COSObjectKey> _preparedKeys = <COSObjectKey>[];
  final List<COSBase> _preparedObjects = <COSBase>[];

  List<COSObjectKey> get preparedKeys => List<COSObjectKey>.unmodifiable(_preparedKeys);

  void prepareStreamObject(COSObjectKey? key, COSBase? object) {
    if (key == null || object == null) {
      return;
    }
    final actual = object is COSObject ? object.object : object;
    _preparedKeys.add(key);
    _preparedObjects.add(actual);
  }

  COSStream writeObjectsToStream(COSStream stream) {
    final count = _preparedKeys.length;
    stream.setItem(COSName.type, COSName.objStm);
    stream.setInt(COSName.n, count);

    final numbers = List<int>.filled(count, 0);
    final buffers = List<Uint8List>.filled(count, Uint8List(0));

    for (var i = 0; i < count; i++) {
      numbers[i] = _preparedKeys[i].objectNumber;
      final builder = BytesBuilder(copy: false);
      _writeObject(builder, _preparedObjects[i], topLevel: true);
      buffers[i] = builder.toBytes();
    }

    final offsetsBuilder = BytesBuilder(copy: false);
    var nextOffset = 0;
    for (var i = 0; i < numbers.length; i++) {
      offsetsBuilder.add(latin1.encode(numbers[i].toString()));
      offsetsBuilder.addByte(0x20);
      offsetsBuilder.add(latin1.encode(nextOffset.toString()));
      offsetsBuilder.addByte(0x20);
      nextOffset += buffers[i].length;
    }
    final offsetsBytes = offsetsBuilder.toBytes();

    final streamBuilder = BytesBuilder(copy: false)
      ..add(offsetsBytes);
    for (final data in buffers) {
      streamBuilder.add(data);
    }
    final uncompressed = streamBuilder.toBytes();

    final compressed = _flate.encode(Uint8List.fromList(uncompressed), COSDictionary(), 0);
    stream.setInt(COSName.first, offsetsBytes.length);
    stream.setItem(COSName.filter, COSName.flateDecode);
    stream.data = compressed;

    return stream;
  }

  void _writeObject(BytesBuilder builder, COSBase object, {required bool topLevel}) {
    if (object is COSObject) {
      if (!topLevel && object.key != null) {
        _writeObjectReference(builder, object.key!);
        return;
      }
      final dereferenced = object.object;
      _writeObject(builder, dereferenced, topLevel: topLevel);
      return;
    }

    if (!topLevel && _compressionPool.contains(object)) {
      final key = _compressionPool.getKey(object);
      if (key == null) {
        throw IOException('Unknown object reference while writing stream');
      }
      _writeObjectReference(builder, key);
      return;
    }

    if (object is COSString) {
      _writeCOSString(builder, object);
    } else if (object is COSFloat) {
      builder.add(latin1.encode(object.toString()));
      builder.addByte(0x20);
    } else if (object is COSInteger) {
      builder.add(latin1.encode(object.intValue.toString()));
      builder.addByte(0x20);
    } else if (object is COSBoolean) {
      builder.add(latin1.encode(object.value ? 'true' : 'false'));
      builder.addByte(0x20);
    } else if (object is COSName) {
      builder.add(latin1.encode(object.toString()));
      builder.addByte(0x20);
    } else if (object is COSArray) {
      builder.addByte(0x5b);
      for (final value in object) {
        _writeObject(builder, value, topLevel: false);
      }
      builder.addByte(0x5d);
      builder.addByte(0x20);
    } else if (object is COSDictionary) {
      builder.add(latin1.encode('<<'));
      for (final entry in object.entries) {
        _writeObject(builder, entry.key, topLevel: true);
        _writeObject(builder, entry.value, topLevel: false);
      }
      builder.add(latin1.encode('>>'));
      builder.addByte(0x20);
    } else if (object is COSNull) {
      _writeCOSNull(builder);
    } else {
      throw IOException('Unsupported COS type in object stream: ${object.runtimeType}');
    }
  }

  void _writeCOSString(BytesBuilder builder, COSString string) {
    if (string.isHex) {
      builder.add(latin1.encode('<'));
      for (final byte in string.bytes) {
        builder.add(latin1.encode(byte.toRadixString(16).padLeft(2, '0').toUpperCase()));
      }
      builder.add(latin1.encode('>'));
    } else {
      builder.addByte(0x28);
      for (final byte in string.bytes) {
        switch (byte) {
          case 0x08:
            builder.add(latin1.encode('\\b'));
            break;
          case 0x09:
            builder.add(latin1.encode('\\t'));
            break;
          case 0x0a:
            builder.add(latin1.encode('\\n'));
            break;
          case 0x0c:
            builder.add(latin1.encode('\\f'));
            break;
          case 0x0d:
            builder.add(latin1.encode('\\r'));
            break;
          case 0x28:
            builder.add(latin1.encode('\\('));
            break;
          case 0x29:
            builder.add(latin1.encode('\\)'));
            break;
          case 0x5c:
            builder.add(latin1.encode('\\\\'));
            break;
          default:
            if (byte < 0x20 || byte > 0x7e) {
              final octal = byte.toRadixString(8).padLeft(3, '0');
              builder.add(latin1.encode('\\$octal'));
            } else {
              builder.addByte(byte);
            }
        }
      }
      builder.addByte(0x29);
    }
    builder.addByte(0x20);
  }

  void _writeObjectReference(BytesBuilder builder, COSObjectKey key) {
    builder
      ..add(latin1.encode('${key.objectNumber}'))
      ..addByte(0x20)
      ..add(latin1.encode('${key.generationNumber}'))
      ..addByte(0x20)
      ..addByte(0x52)
      ..addByte(0x20);
  }

  void _writeCOSNull(BytesBuilder builder) {
    builder.add(latin1.encode('null '));
  }
}
