import 'dart:typed_data';

import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/entropy/decoder/byte_input_buffer.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/io/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('ByteInputBuffer parity', () {
    test('readSequenceAndEof reproduces Java behavior', () {
      final buffer = ByteInputBuffer(Uint8List.fromList([0x01, 0x7F, 0xFF]));
      expect(buffer.read(), 0x01);
      expect(buffer.read(), 0x7F);
      expect(buffer.read(), 0xFF);
      expect(buffer.read(), -1);
      expect(buffer.readChecked, throwsA(isA<EOFException>()));
    });

    test('setByteArray switches to new window', () {
      final first = Uint8List.fromList([10, 11, 12, 13]);
      final second = Uint8List.fromList([20, 21, 22, 23, 24]);
      final buffer = ByteInputBuffer(first);

      expect(buffer.read(), 10);
      expect(buffer.read(), 11);

      buffer.setByteArray(second, 1, 3);
      expect(buffer.read(), 21);
      expect(buffer.read(), 22);
      expect(buffer.read(), 23);
      expect(buffer.read(), -1);

      buffer.setByteArray(second, 0, second.length);
      expect(buffer.read(), 20);
    });

    test('addByteArray appends data after shifting unread bytes', () {
      final buffer = ByteInputBuffer(Uint8List.fromList([40, 41, 42, 43]));
      expect(buffer.read(), 40);
      expect(buffer.read(), 41);

      final extra = Uint8List.fromList([100, 101, 102]);
      buffer.addByteArray(extra, 0, extra.length);

      final remaining = <int>[];
      for (var i = 0; i < 5; i++) {
        remaining.add(buffer.read());
      }
      expect(remaining, [42, 43, 100, 101, 102]);
    });
  });
}
