import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/random_access_output_stream.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';

void main() {
  group('RandomAccessOutputStream', () {
    test('write and read back', () {
      final buffer = RandomAccessReadWriteBuffer();
      final stream = RandomAccessOutputStream(buffer);

      stream.writeBytes(Uint8List.fromList(<int>[1, 2, 3]));
      stream.write(4);
      stream.flush();

      buffer.seek(0);
      final data = Uint8List(buffer.length);
      buffer.readBuffer(data);
      expect(data, orderedEquals(<int>[1, 2, 3, 4]));

      stream.close();
    });

    test('write after close throws', () {
      final buffer = RandomAccessReadWriteBuffer();
      final stream = RandomAccessOutputStream(buffer);
      stream.close();

      expect(() => stream.write(1), throwsA(isA<IOException>()));
    });

    test('write bytes with offset and length', () {
      final buffer = RandomAccessReadWriteBuffer();
      final stream = RandomAccessOutputStream(buffer);

      final bytes = Uint8List.fromList(<int>[0, 1, 2, 3, 4, 5]);
      stream.writeBytes(bytes, 2, 3);

      buffer.seek(0);
      final data = Uint8List(buffer.length);
      buffer.readBuffer(data);
      expect(data, orderedEquals(<int>[2, 3, 4]));

      stream.close();
    });
  });
}
