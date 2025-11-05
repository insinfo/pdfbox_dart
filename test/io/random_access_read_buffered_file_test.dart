import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/io/random_access_read_buffered_file.dart';

void main() {
  group('RandomAccessReadBufferedFile', () {
    late File tempFile;
    late RandomAccessReadBufferedFile reader;

    setUp(() {
      final tempDir = Directory.systemTemp.createTempSync('rar_buffered_file');
      tempFile = File('${tempDir.path}${Platform.pathSeparator}buffered.dat');
      tempFile.writeAsBytesSync(List<int>.generate(16, (i) => i));
      reader = RandomAccessReadBufferedFile(tempFile.path);
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

    test('basic read semantics', () {
      expect(reader.position, 0);
      expect(reader.read(), 0);
      expect(reader.read(), 1);
      expect(reader.position, 2);

      final buffer = Uint8List(4);
      expect(reader.readBuffer(buffer), 4);
      expect(buffer, orderedEquals(<int>[2, 3, 4, 5]));
      expect(reader.position, 6);
    });

    test('seek and eof', () {
      reader.seek(10);
      expect(reader.position, 10);
      expect(reader.isEOF, isFalse);
      reader.seek(reader.length);
      expect(reader.isEOF, isTrue);
      expect(reader.read(), -1);
      expect(reader.readBuffer(Uint8List(4)), -1);
    });

    test('peek does not move position', () {
      expect(reader.peek(), 0);
      expect(reader.position, 0);
    });

    test('create view reads window', () {
      final view = reader.createView(4, 6);
      expect(view.position, 0);
      final data = Uint8List(6);
      expect(view.readBuffer(data), 6);
      expect(data, orderedEquals(<int>[4, 5, 6, 7, 8, 9]));
      view.close();
    });

    test('close toggles state', () {
      expect(reader.isClosed, isFalse);
      reader.close();
      expect(reader.isClosed, isTrue);
      expect(() => reader.read(), throwsA(isA<Exception>()));
    });
  });
}
