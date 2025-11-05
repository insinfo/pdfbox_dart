import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/memory_usage_setting.dart';
import 'package:pdfbox_dart/src/io/random_access.dart';
import 'package:pdfbox_dart/src/io/scratch_file.dart';

void main() {
  const pageSize = 4096;
  const iterations = 3;

  group('ScratchFileBuffer', () {
    test('seek across pages without EOF', () {
      final scratchFile = ScratchFile(MemoryUsageSetting.setupMainMemoryOnly());
      addTearDown(scratchFile.close);

  final RandomAccess buffer = scratchFile.createBuffer();
      final bytes = Uint8List(pageSize);

      for (var i = 0; i < iterations; i++) {
        final start = buffer.position;
        buffer.writeBytes(bytes);
        final mid = buffer.position;
        expect(mid - start, pageSize);
        buffer.writeBytes(bytes);
        final end = buffer.position;
        expect(end - mid, pageSize);
        buffer.seek(0);
        buffer.seek(i * 2 * pageSize);
      }

      buffer.close();
    });

    test('buffer length follows writes', () {
      final scratchFile = ScratchFile(MemoryUsageSetting.setupMainMemoryOnly());
      addTearDown(scratchFile.close);

  final RandomAccess buffer = scratchFile.createBuffer();
      final bytes = Uint8List(pageSize);
      buffer.writeBytes(bytes);
      expect(buffer.length, pageSize);
      buffer.close();
    });

    test('seek validation', () {
      final scratchFile = ScratchFile(MemoryUsageSetting.setupMainMemoryOnly());
      addTearDown(scratchFile.close);

  final RandomAccess buffer = scratchFile.createBuffer();
      buffer.writeBytes(Uint8List(pageSize));
      expect(() => buffer.seek(-1), throwsA(isA<IOException>()));
      expect(() => buffer.seek(pageSize + 1), throwsA(isA<EofException>()));
      buffer.close();
    });

    test('eof flag toggles at boundary', () {
      final scratchFile = ScratchFile(MemoryUsageSetting.setupMainMemoryOnly());
      addTearDown(scratchFile.close);

  final RandomAccess buffer = scratchFile.createBuffer();
      buffer.writeBytes(Uint8List(pageSize));
      buffer.seek(0);
      expect(buffer.isEOF, isFalse);
      buffer.seek(pageSize);
      expect(buffer.isEOF, isTrue);
      buffer.close();
    });

    test('operations after close fail', () {
      final scratchFile = ScratchFile(MemoryUsageSetting.setupMainMemoryOnly());
      addTearDown(scratchFile.close);

  final RandomAccess buffer = scratchFile.createBuffer();
      buffer.writeBytes(Uint8List(pageSize));
      buffer.close();
      expect(() => buffer.seek(0), throwsA(isA<IOException>()));
    });

    test('closing scratch file closes buffers', () {
      final scratchFile = ScratchFile(MemoryUsageSetting.setupMainMemoryOnly());

      final bytes = Uint8List(pageSize);
  final RandomAccess buffer1 = scratchFile.createBuffer()..writeBytes(bytes);
  final RandomAccess buffer2 = scratchFile.createBuffer()..writeBytes(bytes);
  final RandomAccess buffer3 = scratchFile.createBuffer()..writeBytes(bytes);
  final RandomAccess buffer4 = scratchFile.createBuffer()..writeBytes(bytes);

      buffer1.close();
      buffer3.close();

      expect(buffer1.isClosed, isTrue);
      expect(buffer2.isClosed, isFalse);
      expect(buffer3.isClosed, isTrue);
      expect(buffer4.isClosed, isFalse);

      scratchFile.close();

      expect(buffer2.isClosed, isTrue);
      expect(buffer4.isClosed, isTrue);
    });

    test('views are not supported', () {
      final scratchFile = ScratchFile(MemoryUsageSetting.setupMainMemoryOnly());
      addTearDown(scratchFile.close);

  final RandomAccess buffer = scratchFile.createBuffer();
      buffer.writeBytes(Uint8List.fromList(<int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));
      expect(
        () => buffer.createView(0, 10),
        throwsA(isA<UnsupportedError>()),
      );
      buffer.close();
    });
  });
}
