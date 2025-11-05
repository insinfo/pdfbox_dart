import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/io/random_access_read_unbuffered_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/io/ttc_data_stream.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:test/test.dart';

void main() {
  group('RandomAccessReadDataStream', () {
    test('reads primitive types correctly', () {
      final bytes = Uint8List.fromList([
        0x7f,
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        // unsigned int 0x090A0B0C
        0x09,
        0x0a,
        0x0b,
        0x0c,
        // fixed 1.5 (0x00018000)
        0x00,
        0x01,
        0x80,
        0x00,
        // tag 'TEST'
        0x54,
        0x45,
        0x53,
        0x54,
        // seconds since 1904 (1970-01-01 UTC)
        0x00,
        0x00,
        0x00,
        0x00,
        0x7c,
        0x25,
        0xb0,
        0x80,
      ]);
      final stream = RandomAccessReadDataStream.fromData(bytes);

  expect(stream.readUnsignedByte(), 0x7f);
  expect(stream.readUnsignedShort(), 0x0102);
  expect(stream.readUnsignedShort(), 0x0304);
  expect(stream.readUnsignedShort(), 0x0506);
  expect(stream.readUnsignedShort(), 0x0708);
  expect(stream.readUnsignedInt(), 0x090a0b0c);
      expect(stream.read32Fixed(), closeTo(1.5, 1e-6));
      expect(stream.readTag(), 'TEST');
      expect(stream.readInternationalDate().toUtc(), DateTime.utc(1970, 1, 1));
    });

    test('seek and createSubView', () {
      final bytes = Uint8List.fromList(List<int>.generate(16, (i) => i));
      final stream = RandomAccessReadDataStream.fromData(bytes);
      stream.seek(4);
      expect(stream.currentPosition, 4);
      expect(stream.readUnsignedByte(), 4);
      final view = stream.createSubView(4);
      expect(view, isNotNull);
      final buffer = Uint8List(4);
      view!.readBuffer(buffer);
      expect(buffer, [5, 6, 7, 8]);
    });

    test('openOriginalDataStream yields complete data', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final stream = RandomAccessReadDataStream.fromData(bytes);
      final collected = <int>[];
      await for (final chunk in stream.openOriginalDataStream()) {
        collected.addAll(chunk);
      }
      expect(collected, bytes);
    });
  });

  group('RandomAccessReadUnbufferedDataStream', () {
    test('reading delegates to source', () {
      final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
      final source = RandomAccessReadBuffer.fromBytes(bytes);
      final stream = RandomAccessReadUnbufferedDataStream(source);

      expect(stream.readUnsignedByte(), 0);
      stream.seek(2);
      expect(stream.readUnsignedShort(), 0x0203);
      stream.seek(0);
      expect(stream.readLong(), 0x0001020304050607);
    });

    test('openOriginalDataStream keeps cursor', () async {
      final bytes = Uint8List.fromList(List<int>.generate(12, (i) => i));
      final source = RandomAccessReadBuffer.fromBytes(bytes);
      final stream = RandomAccessReadUnbufferedDataStream(source);
      stream.seek(5);
      final before = stream.currentPosition;
      final collected = <int>[];
      await for (final chunk in stream.openOriginalDataStream()) {
        collected.addAll(chunk);
      }
      expect(stream.currentPosition, before);
      expect(collected, bytes);
    });
  });

  group('TtcDataStream', () {
    test('delegates without closing underlying stream', () async {
      final bytes = Uint8List.fromList([10, 20, 30, 40]);
      final delegate = RandomAccessReadDataStream.fromData(bytes);
      final stream = TtcDataStream(delegate);
      expect(stream.readUnsignedByte(), 10);
      stream.seek(2);
      expect(stream.readUnsignedByte(), 30);
      await expectLater(
        stream.openOriginalDataStream(),
        emitsInOrder([
          equals(bytes),
          emitsDone,
        ]),
      );
      // closing TTC stream should not close delegate; we can still read
      stream.close();
      expect(delegate.readUnsignedByte(), 40);
    });
  });
}
