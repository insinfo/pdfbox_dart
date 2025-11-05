import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/io/random_access_read_memory_mapped_file.dart';

void main() {
  group('RandomAccessReadMemoryMappedFile', () {
    late File tempFile;
    late RandomAccessReadMemoryMappedFile reader;

    setUp(() {
      final tempDir = Directory.systemTemp.createTempSync('rar_mmap_file');
      tempFile = File('${tempDir.path}${Platform.pathSeparator}mmap.dat');
      tempFile.writeAsBytesSync(List<int>.generate(20, (i) => i));
      reader = RandomAccessReadMemoryMappedFile(tempFile.path);
    });

    tearDown(() {
      reader.close();
      final dir = tempFile.parent;
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('read across segments', () {
      final buffer = Uint8List(5);
      expect(reader.readBuffer(buffer), 5);
      expect(buffer, orderedEquals(<int>[0, 1, 2, 3, 4]));

      reader.seek(10);
      expect(reader.read(), 10);
      reader.rewind(1);
      expect(reader.peek(), 10);
    });

    test('createView shares data', () {
      final view = reader.createView(5, 8);
      final bytes = Uint8List(8);
      expect(view.readBuffer(bytes), 8);
      expect(bytes, orderedEquals(<int>[5, 6, 7, 8, 9, 10, 11, 12]));
      view.close();
    });

    test('isClosed flag follows delegate', () {
      expect(reader.isClosed, isFalse);
      reader.close();
      expect(reader.isClosed, isTrue);
    });
  });
}
