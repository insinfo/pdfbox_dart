import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/io/random_access_input_stream.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';

void main() {
  group('RandomAccessInputStream', () {
    RandomAccessInputStream _buildStream() {
      final data = Uint8List.fromList(List<int>.generate(11, (i) => i));
      return RandomAccessInputStream(RandomAccessReadBuffer.fromBytes(data));
    }

    test('position and skip', () {
      final stream = _buildStream();

      expect(stream.available(), 11);
      expect(stream.skip(5), 5);
      expect(stream.read(), 5);
      expect(stream.available(), 5);
      expect(stream.skip(-10), 0);

      stream.close();
    });

    test('position and read bytes', () {
      final stream = _buildStream();

      expect(stream.available(), 11);
      expect(stream.read(), 0);
      expect(stream.read(), 1);
      expect(stream.read(), 2);
      expect(stream.available(), 8);

      stream.close();
    });

    test('skip past EOF', () {
      final stream = _buildStream();

      expect(stream.skip(12), 12);
      expect(stream.available(), 0);
      expect(stream.read(), -1);
      expect(stream.readInto(Uint8List(1)), -1);

      stream.close();
    });

    test('read buffers', () {
      final stream = _buildStream();

      final buffer = Uint8List(4);
      expect(stream.readInto(buffer), 4);
      expect(buffer, orderedEquals(<int>[0, 1, 2, 3]));
      expect(stream.available(), 7);

      expect(stream.readInto(buffer, 1, 2), 2);
      expect(buffer, orderedEquals(<int>[0, 4, 5, 3]));
      expect(stream.available(), 5);

      stream.close();
    });

    test('empty source', () {
      final empty = RandomAccessInputStream(RandomAccessReadBuffer.fromBytes(Uint8List(0)));

      expect(empty.read(), -1);
      expect(empty.readInto(Uint8List(6)), -1);
      expect(empty.available(), 0);

      empty.close();
    });
  });
}
