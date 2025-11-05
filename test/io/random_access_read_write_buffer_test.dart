import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';

void main() {
  group('RandomAccessReadWriteBuffer', () {
    test('close marks buffer as closed', () {
      final buffer = RandomAccessReadWriteBuffer();
      buffer.writeBytes(Uint8List.fromList(<int>[1, 2, 3, 4]));
      expect(buffer.isClosed, isFalse);
      buffer.close();
      expect(buffer.isClosed, isTrue);
    });

    test('clear resets buffer state', () {
      final buffer = RandomAccessReadWriteBuffer(4);
      buffer.writeBytes(Uint8List.fromList(List<int>.generate(10, (i) => i + 1)));
      expect(buffer.length, 10);
      expect(buffer.position, 10);
      buffer.clear();
      expect(buffer.isClosed, isFalse);
      expect(buffer.length, 0);
      expect(buffer.position, 0);
      buffer.close();
    });

    test('write byte extends length', () {
      final buffer = RandomAccessReadWriteBuffer();
      expect(buffer.length, 0);
      buffer.writeByte(1);
      buffer.writeByte(2);
      buffer.writeByte(3);
      expect(buffer.length, 3);
      buffer.close();
    });

    test('write bytes across pages', () {
      final buffer = RandomAccessReadWriteBuffer(5);
      buffer.writeBytes(Uint8List.fromList(List<int>.generate(11, (i) => i + 1)));
      expect(buffer.length, 11);
      buffer.seek(0);
      final readBack = Uint8List(11);
      expect(buffer.readBuffer(readBack), 11);
      expect(readBack.first, 1);
      expect(readBack[6], 7);
      expect(readBack.last, 11);
      buffer.close();
    });

    test('seek validates input', () {
      final buffer = RandomAccessReadWriteBuffer();
      buffer.writeBytes(Uint8List.fromList(List<int>.generate(8, (i) => i)));
      expect(() => buffer.seek(-1), throwsA(isA<IOException>()));
      buffer.close();
    });

    test('eof flag toggles with seek', () {
      final buffer = RandomAccessReadWriteBuffer();
      buffer.writeBytes(Uint8List(RandomAccessReadBuffer.defaultChunkSize4KB));
      buffer.seek(0);
      expect(buffer.isEOF, isFalse);
      buffer.seek(RandomAccessReadBuffer.defaultChunkSize4KB);
      expect(buffer.isEOF, isTrue);
      buffer.close();
    });
  });
}
