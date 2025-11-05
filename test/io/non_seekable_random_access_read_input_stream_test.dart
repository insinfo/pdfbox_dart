import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/non_seekable_random_access_read_input_stream.dart';

void main() {
  group('NonSeekableRandomAccessReadInputStream', () {
    test('position and skip', () {
      final rar = NonSeekableRandomAccessReadInputStream.fromBytes(
        Uint8List.fromList(List<int>.generate(11, (i) => i)),
      );

      addTearDown(rar.close);

      expect(rar.position, 0);
      rar.skip(5);
      expect(rar.read(), 5);
      expect(rar.position, 6);
    });

    test('position and read', () {
      final rar = NonSeekableRandomAccessReadInputStream.fromBytes(
        Uint8List.fromList(List<int>.generate(11, (i) => i)),
      );

      expect(rar.position, 0);
      expect(rar.read(), 0);
      expect(rar.read(), 1);
      expect(rar.read(), 2);
      expect(rar.position, 3);

      expect(rar.isClosed, isFalse);
      rar.close();
      expect(rar.isClosed, isTrue);
    });

    test('seek throws', () {
      final rar = NonSeekableRandomAccessReadInputStream.fromBytes(
        Uint8List.fromList(List<int>.generate(11, (i) => i)),
      );

      addTearDown(rar.close);

      expect(() => rar.seek(3), throwsA(isA<IOException>()));
    });

    test('read buffer updates position', () {
      final rar = NonSeekableRandomAccessReadInputStream.fromBytes(
        Uint8List.fromList(List<int>.generate(11, (i) => i)),
      );

      addTearDown(rar.close);

      expect(rar.position, 0);
      final buffer = Uint8List(4);
      expect(rar.readBuffer(buffer), 4);
      expect(buffer, orderedEquals(<int>[0, 1, 2, 3]));
      expect(rar.position, 4);

      expect(rar.readBuffer(buffer, 1, 2), 2);
      expect(buffer, orderedEquals(<int>[0, 4, 5, 3]));
      expect(rar.position, 6);
    });

    test('peek preserves position', () {
      final rar = NonSeekableRandomAccessReadInputStream.fromBytes(
        Uint8List.fromList(List<int>.generate(11, (i) => i)),
      );

      addTearDown(rar.close);

      rar.skip(6);
      expect(rar.position, 6);
      expect(rar.peek(), 6);
      expect(rar.position, 6);
    });

    test('unread bytes rewinds correctly', () {
      final rar = NonSeekableRandomAccessReadInputStream.fromBytes(
        Uint8List.fromList(List<int>.generate(11, (i) => i)),
      );

      addTearDown(rar.close);

      expect(rar.position, 0);
      expect(rar.read(), 0);
      expect(rar.read(), 1);
      final readBytes = Uint8List(6);
      expect(rar.readBuffer(readBytes), 6);
      expect(rar.position, 8);
      rar.rewind(readBytes.length);
      expect(rar.position, 2);
      expect(rar.read(), 2);
      expect(rar.position, 3);
      expect(rar.readBuffer(readBytes, 2, 4), 4);
      expect(rar.position, 7);
      rar.rewind(4);
      expect(rar.position, 3);
    });

    test('rewind across buffers and EOF reset', () {
      final data = Uint8List.fromList(List<int>.generate(20, (i) => i));
      final rar = NonSeekableRandomAccessReadInputStream.fromBytes(data);
      addTearDown(rar.close);

      final first = Uint8List(10);
      expect(rar.readBuffer(first), 10);
      expect(rar.readBuffer(Uint8List(10)), 10);
      expect(rar.read(), -1);
      expect(rar.isEOF, isTrue);
      rar.rewind(4);
      expect(rar.isEOF, isFalse);
      expect(rar.read(), data[data.length - 4]);
    });

    test('buffer switch around multiples of 4096', () async {
      final path = await File('${Directory.systemTemp.path}/len4096_${DateTime.now().microsecondsSinceEpoch}.tmp')
          .create();
      addTearDown(() async {
        if (await path.exists()) {
          await path.delete();
        }
      });
      await path.writeAsBytes(Uint8List(4096));
      final raf = await path.open(mode: FileMode.read);
      final rar = NonSeekableRandomAccessReadInputStream.fromRandomAccessFile(raf);
      addTearDown(rar.close);

      expect(rar.read(), 0);
    });

    test('rewind across buffers regression', () {
      final bytes = Uint8List(4096 + 5);
      const rewindSize = 7;
      bytes[bytes.length - rewindSize] = 123;
      final rar = NonSeekableRandomAccessReadInputStream.fromBytes(bytes);
      addTearDown(rar.close);

      expect(rar.readBuffer(Uint8List(bytes.length - rewindSize)), bytes.length - rewindSize);
      expect(rar.readBuffer(Uint8List(rewindSize)), rewindSize);
      expect(rar.read(), -1);
      expect(rar.isEOF, isTrue);
      rar.rewind(rewindSize);
      expect(rar.read(), 123);
    });

    test('access after close throws', () {
      final rar = NonSeekableRandomAccessReadInputStream.fromBytes(Uint8List.fromList([1]));
      expect(rar.read(), 1);
      expect(rar.read(), -1);
      rar.close();
      expect(() => rar.read(), throwsA(isA<IOException>()));
    });

    test('PDFBOX-5161 regression', () {
      final rar = NonSeekableRandomAccessReadInputStream.fromBytes(Uint8List(4099));
      addTearDown(rar.close);

      final buf = Uint8List(4096);
      expect(rar.readBuffer(buf), 4096);
      expect(rar.readBuffer(buf, 0, 3), 3);
    });

    test('PDFBOX-5965 rewind near EOF', () {
      final data = Uint8List.fromList(List<int>.generate(11, (i) => i));
      final rar = NonSeekableRandomAccessReadInputStream.fromBytes(data);
      addTearDown(rar.close);

      final scratch = Uint8List(6);
      expect(rar.readBuffer(scratch), 6);
      expect(rar.readBuffer(Uint8List(4)), 4);
      expect(rar.read(), 10);
      expect(rar.read(), -1);
      expect(rar.isEOF, isTrue);
      rar.rewind(4);
      expect(rar.isEOF, isFalse);
      expect(rar.read(), 7);
      expect(rar.read(), 8);
      expect(rar.read(), 9);
      expect(rar.read(), 10);
      expect(rar.read(), -1);
    });

  });
}
