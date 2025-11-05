import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';

void main() {
  group('RandomAccessReadBuffer', () {
    test('position and skip', () {
      final buffer = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(List<int>.generate(11, (i) => i)));

      expect(buffer.position, 0);
      buffer.skip(5);
      expect(buffer.read(), 5);
      expect(buffer.position, 6);
      buffer.close();
    });

    test('position and read bytes', () {
      final buffer = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(List<int>.generate(11, (i) => i)));

      expect(buffer.position, 0);
      final chunk = Uint8List(4);
      expect(buffer.readBuffer(chunk), 4);
      expect(chunk, orderedEquals(<int>[0, 1, 2, 3]));
      expect(buffer.position, 4);

      expect(buffer.readBuffer(chunk, 1, 2), 2);
      expect(chunk, orderedEquals(<int>[0, 4, 5, 3]));
      expect(buffer.position, 6);

      buffer.close();
    });

    test('seek and EOF handling', () {
      final buffer = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(List<int>.generate(11, (i) => i)));

      buffer.seek(3);
      expect(buffer.position, 3);
      expect(() => buffer.seek(-1), throwsA(isA<IOException>()));

      expect(buffer.isEOF, isFalse);
      buffer.seek(20);
      expect(buffer.isEOF, isTrue);
      expect(buffer.read(), -1);
      expect(buffer.readBuffer(Uint8List(1)), -1);

      buffer.close();
      expect(() => buffer.read(), throwsA(isA<IOException>()));
    });

    test('peek preserves position', () {
      final buffer = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(List<int>.generate(11, (i) => i)));

      buffer.skip(6);
      expect(buffer.position, 6);
      expect(buffer.peek(), 6);
      expect(buffer.position, 6);

      buffer.close();
    });

    test('rewind restores previous bytes', () {
      final buffer = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(List<int>.generate(11, (i) => i)));

      expect(buffer.read(), 0);
      expect(buffer.read(), 1);
      final readBytes = Uint8List(6);
      expect(buffer.readBuffer(readBytes), 6);
      expect(buffer.position, 8);
      buffer.rewind(readBytes.length);
      expect(buffer.position, 2);
      expect(buffer.read(), 2);
      expect(buffer.position, 3);
      expect(buffer.readBuffer(readBytes, 2, 4), 4);
      expect(buffer.position, 7);
      buffer.rewind(4);
      expect(buffer.position, 3);

      buffer.close();
    });

    test('empty buffer behaviour', () {
      final buffer = RandomAccessReadBuffer.fromBytes(Uint8List(0));

      expect(buffer.read(), -1);
      expect(buffer.peek(), -1);
      expect(buffer.readBuffer(Uint8List(6)), -1);
      buffer.seek(0);
      expect(buffer.position, 0);
      buffer.seek(6);
      expect(buffer.position, 0);
      expect(buffer.isEOF, isTrue);
      expect(() => buffer.rewind(3), throwsA(isA<IOException>()));

      buffer.close();
    });

    test('view exposes slice', () {
      final buffer = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(List<int>.generate(11, (i) => i)));
      final view = buffer.createView(3, 5);

      expect(view.position, 0);
      expect(view.read(), 3);
      expect(view.read(), 4);
      expect(view.read(), 5);
      expect(view.position, 3);

      view.close();
      buffer.close();
    });
  });
}
