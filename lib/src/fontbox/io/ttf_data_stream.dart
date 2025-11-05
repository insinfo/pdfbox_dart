import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/closeable.dart';
import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/random_access_read.dart';

/// Base class for reading binary font data using TrueType semantics.
abstract class TtfDataStream implements Closeable {
  static const _secondsBetween1904And1970 = 2082844800; // helper for DateTime conversion

  double read32Fixed() {
    final integerPart = readSignedShort();
    final fractionalPart = readUnsignedShort();
    return integerPart + (fractionalPart / 65536.0);
  }

  String readString(int length, [Encoding encoding = latin1]) {
    final bytes = readBytes(length);
    return encoding.decode(bytes);
  }

  int read();

  int readLong();

  int readUnsignedByte() {
    final value = read();
    if (value == -1) {
      throw EofException('premature EOF');
    }
    return value;
  }

  int readSignedByte() {
    final value = readUnsignedByte();
    return value <= 0x7f ? value : value - 0x100;
  }

  int readUnsignedShort() {
    final b1 = readUnsignedByte();
    final b2 = readUnsignedByte();
    return (b1 << 8) | b2;
  }

  int readUnsignedInt() {
    final b1 = readUnsignedByte();
    final b2 = readUnsignedByte();
    final b3 = readUnsignedByte();
    final b4 = readUnsignedByte();
    return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
  }

  List<int> readUnsignedByteArray(int length) {
    final values = List<int>.filled(length, 0);
    for (var i = 0; i < length; i++) {
      values[i] = readUnsignedByte();
    }
    return values;
  }

  List<int> readUnsignedShortArray(int length) {
    final values = List<int>.filled(length, 0);
    for (var i = 0; i < length; i++) {
      values[i] = readUnsignedShort();
    }
    return values;
  }

  int readSignedShort() => readUnsignedShort().toSigned(16);

  DateTime readInternationalDate() {
    final secondsSince1904 = readLong();
    final secondsSinceUnixEpoch = secondsSince1904 - _secondsBetween1904And1970;
    return DateTime.fromMillisecondsSinceEpoch(
      secondsSinceUnixEpoch * 1000,
      isUtc: true,
    );
  }

  String readTag() {
    final bytes = readBytes(4);
    return ascii.decode(bytes);
  }

  void seek(int position);

  Uint8List readBytes(int length) {
    final data = Uint8List(length);
    var offset = 0;
    while (offset < length) {
      final readNow = readInto(data, offset, length - offset);
      if (readNow <= 0) {
        throw IOException('Unexpected end of TTF stream reached');
      }
      offset += readNow;
    }
    return data;
  }

  int readInto(Uint8List buffer, int offset, int length);

  RandomAccessRead? createSubView(int length) => null;

  int get currentPosition;

  Stream<List<int>> openOriginalDataStream();

  int get originalDataSize;
}
