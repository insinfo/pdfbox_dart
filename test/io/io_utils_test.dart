import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/io/io_utils.dart';

void main() {
  group('IOUtils stream cache factories', () {
    test('memory-only cache uses in-memory buffers', () {
      final factory = IOUtils.createMemoryOnlyStreamCache();
      final cache = factory();
      final buffer = cache.createBuffer();

      buffer.writeByte(42);
      expect(buffer.length, 1);
      buffer.seek(0);
      expect(buffer.read(), 42);

      buffer.close();
      cache.close();
    });

    test('temp-file cache allocates scratch buffer', () {
      final factory = IOUtils.createTempFileOnlyStreamCache();
      final cache = factory();
      final buffer = cache.createBuffer();

      buffer.writeBytes(Uint8List.fromList(<int>[1, 2, 3]));
      expect(buffer.length, 3);
      buffer.seek(0);
      expect(buffer.readBuffer(Uint8List(3)), 3);

      buffer.close();
      cache.close();
    });
  });
}
