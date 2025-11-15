import 'dart:io';

import 'msg_logger.dart';
import 'msg_printer.dart';

/// Stream-backed implementation of [MsgLogger].
class StreamMsgLogger implements MsgLogger {
  StreamMsgLogger(StringSink out, StringSink err, {int lineWidth = 78})
      : _out = out,
        _err = err,
        _printer = MsgPrinter(lineWidth);

  factory StreamMsgLogger.stdout({int lineWidth = 78}) => StreamMsgLogger(
        stdout,
        stderr,
        lineWidth: lineWidth,
      );

  final StringSink _out;
  final StringSink _err;
  final MsgPrinter _printer;

  @override
  void printmsg(int severity, String message) {
    switch (severity) {
      case MsgLogger.log:
        _printer.print(_out, 0, '[LOG]: '.length, '[LOG]: $message');
        break;
      case MsgLogger.info:
        _printer.print(_out, 0, '[INFO]: '.length, '[INFO]: $message');
        break;
      case MsgLogger.warning:
        _printer.print(_err, 0, '[WARNING]: '.length, '[WARNING]: $message');
        break;
      case MsgLogger.error:
        _printer.print(_err, 0, '[ERROR]: '.length, '[ERROR]: $message');
        break;
      default:
        throw ArgumentError('Severity $severity not valid.');
    }
  }

  @override
  void println(String message, int firstLineIndent, int indent) {
    _printer.print(_out, firstLineIndent, indent, message);
  }

  @override
  void flush() {
    if (_out case final IOSink outSink) {
      outSink.flush();
    }
    if (_err case final IOSink errSink) {
      errSink.flush();
    }
  }
}
