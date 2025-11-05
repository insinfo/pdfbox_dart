import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/random_access_input_stream.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/io/sequence_random_access_read.dart';

void main() {
  group('SequenceRandomAccessRead', () {
    test('concatenates readers and reads sequentially', () {
      final reader1 = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(utf8.encode('string 1 ')));
      final reader2 = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(utf8.encode('and string 2')));

      final sequence = SequenceRandomAccessRead([reader1, reader2]);
      addTearDown(() {
        if (!sequence.isClosed) {
          sequence.close();
        }
      });

      expect(() => sequence.createView(0, 1), throwsUnsupportedError);

      final totalLength = 'string 1 and string 2'.length;
      expect(sequence.length, totalLength);

      final data = Uint8List(totalLength);
      final bytesRead = sequence.readBuffer(data);
      expect(bytesRead, totalLength);
      expect(utf8.decode(data), 'string 1 and string 2');

      // After consumption, attempting to recreate the sequence with closed readers should fail.
      sequence.close();
      expect(() => SequenceRandomAccessRead([reader1, reader2]), throwsArgumentError);
    });

    test('seek, peek, and rewind across segments', () {
      final reader1 = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(utf8.encode('0123456789')));
      final reader2 = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(utf8.encode('abcdefghij')));
  final sequence = SequenceRandomAccessRead([reader1, reader2]);
  addTearDown(sequence.close);

      sequence.seek(4);
      expect(sequence.position, 4);
      expect(sequence.read(), '4'.codeUnitAt(0));
      expect(sequence.position, 5);
      sequence.rewind(1);
      expect(sequence.position, 4);
      expect(sequence.read(), '4'.codeUnitAt(0));
      expect(sequence.peek(), '5'.codeUnitAt(0));
      expect(sequence.position, 5);
      expect(sequence.read(), '5'.codeUnitAt(0));

      sequence.seek(14);
      expect(sequence.position, 14);
      expect(sequence.read(), 'e'.codeUnitAt(0));
      sequence.rewind(1);
      expect(sequence.read(), 'e'.codeUnitAt(0));
      expect(sequence.peek(), 'f'.codeUnitAt(0));
      expect(sequence.read(), 'f'.codeUnitAt(0));
      expect(() => sequence.seek(-1), throwsA(isA<IOException>()));
    });

    test('cross-segment boundaries', () {
      final reader1 = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(utf8.encode('0123456789')));
      final reader2 = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(utf8.encode('abcdefghij')));
  final sequence = SequenceRandomAccessRead([reader1, reader2]);
  addTearDown(sequence.close);

      sequence.seek(9);
      expect(sequence.read(), '9'.codeUnitAt(0));
      sequence.rewind(1);
      expect(sequence.read(), '9'.codeUnitAt(0));
      expect(sequence.peek(), 'a'.codeUnitAt(0));
      expect(sequence.read(), 'a'.codeUnitAt(0));

      sequence.seek(7);
      final buffer = Uint8List(6);
      expect(sequence.readBuffer(buffer), 6);
      expect(utf8.decode(buffer), '789abc');
      expect(sequence.position, 13);

      sequence.rewind(6);
      expect(sequence.position, 7);
      final buffer2 = Uint8List(6);
      expect(sequence.readBuffer(buffer2), 6);
      expect(utf8.decode(buffer2), '789abc');

      sequence.seek(0);
      final startBuffer = Uint8List(6);
      expect(sequence.readBuffer(startBuffer), 6);
      expect(utf8.decode(startBuffer), '012345');
    });

    test('EOF behaviour', () {
      final reader1 = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(utf8.encode('0123456789')));
      final reader2 = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(utf8.encode('abcdefghij')));
      final sequence = SequenceRandomAccessRead([reader1, reader2]);
      addTearDown(sequence.close);

      final totalLength = sequence.length;
      sequence.seek(totalLength - 1);
      expect(sequence.isEOF, isFalse);
      expect(sequence.peek(), 'j'.codeUnitAt(0));
      expect(sequence.isEOF, isFalse);
      expect(sequence.read(), 'j'.codeUnitAt(0));
      expect(sequence.isEOF, isTrue);
      expect(sequence.read(), -1);
      expect(sequence.readBuffer(Uint8List(1)), -1);

      sequence.rewind(5);
      expect(sequence.isEOF, isFalse);
      final bytes = Uint8List(5);
      expect(sequence.readBuffer(bytes), 5);
      expect(utf8.decode(bytes), 'fghij');
      expect(sequence.isEOF, isTrue);

      sequence.seek(totalLength + 10);
      expect(sequence.isEOF, isTrue);
      expect(sequence.position, totalLength);

      expect(sequence.isClosed, isFalse);
      sequence.close();
      expect(sequence.isClosed, isTrue);
      expect(() => sequence.read(), throwsA(isA<IOException>()));
    });

    test('handles empty readers in the list', () {
      final reader1 = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(utf8.encode('0123456789')));
      final empty = RandomAccessReadBuffer.fromBytes(Uint8List(0));
      final reader2 = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(utf8.encode('abcdefghij')));

      final sequence = SequenceRandomAccessRead([reader1, empty, reader2]);
      addTearDown(sequence.close);

      expect(sequence.length, reader1.length + reader2.length);

      final buffer = Uint8List(10);
      sequence.seek(5);
      expect(sequence.readBuffer(buffer), 10);
      expect(utf8.decode(buffer), '56789abcde');

      sequence.rewind(15);
      final buffer2 = Uint8List(5);
      expect(sequence.readBuffer(buffer2), 5);
      expect(utf8.decode(buffer2), '01234');

      final buffer3 = Uint8List(5);
      sequence.seek(sequence.length - 2);
      expect(sequence.readBuffer(buffer3), 2);
      expect(utf8.decode(buffer3.sublist(0, 2)), 'ij');

      sequence.seek(sequence.length);
      expect(sequence.isEOF, isTrue);
    });

    test('PDFBOX-5981 regression', () {
      final readers = [
        RandomAccessReadBuffer.fromBytes(Uint8List(2448)),
        RandomAccessReadBuffer.fromBytes(Uint8List(2412)),
        RandomAccessReadBuffer.fromBytes(Uint8List(2417)),
        RandomAccessReadBuffer.fromBytes(Uint8List(2433)),
        RandomAccessReadBuffer.fromBytes(Uint8List(2432)),
        RandomAccessReadBuffer.fromBytes(Uint8List(2416)),
        RandomAccessReadBuffer.fromBytes(Uint8List(2417)),
        RandomAccessReadBuffer.fromBytes(Uint8List(2266)),
      ];

      final sequence = SequenceRandomAccessRead(readers);
      addTearDown(sequence.close);

  final rais = RandomAccessInputStream(sequence);

  expect(rais.readInto(Uint8List(0), 0, 0), 0);
  final buffer = Uint8List(sequence.length);
  final allBytes = rais.readInto(buffer);
  expect(allBytes, sequence.length);
      expect(sequence.length, 19241);

      rais.close();
    });
  });
}
