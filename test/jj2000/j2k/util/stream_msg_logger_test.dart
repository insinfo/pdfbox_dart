import 'package:pdfbox_dart/src/jj2000/j2k/util/msg_logger.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/util/stream_msg_logger.dart';
import 'package:test/test.dart';

void main() {
  group('StreamMsgLogger', () {
    test('printmsg routes by severity', () {
      final out = _BufferSink();
      final err = _BufferSink();
      final logger = StreamMsgLogger(out, err, lineWidth: 40);

      logger.printmsg(MsgLogger.info, 'ready');
      expect(out.toString(), contains('[INFO]: ready'));
      expect(err.toString(), isEmpty);

      logger.printmsg(MsgLogger.warning, 'careful');
      expect(err.toString(), contains('[WARNING]: careful'));
    });

    test('println respects indentation and wrapping', () {
      final out = _BufferSink();
      final err = _BufferSink();
      final logger = StreamMsgLogger(out, err, lineWidth: 12);

      logger.println('alpha beta gamma', 2, 4);

      final output = out.toString();
      expect(output.startsWith('  alpha'), isTrue);
      expect(output.contains('\n'), isTrue);
    });

    test('printmsg rejects invalid severity', () {
      final out = _BufferSink();
      final err = _BufferSink();
      final logger = StreamMsgLogger(out, err, lineWidth: 40);

      expect(() => logger.printmsg(99, 'invalid'), throwsArgumentError);
    });
  });
}

class _BufferSink implements StringSink {
  final StringBuffer _buffer = StringBuffer();

  @override
  void write(Object? obj) => _buffer.write(obj);

    @override
    void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _buffer.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  void writeln([Object? obj = '']) => _buffer.writeln(obj);

  @override
  String toString() => _buffer.toString();
}
