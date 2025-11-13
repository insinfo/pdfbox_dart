import 'dart:typed_data';

import '../../io/random_access_write.dart';

/// Simplified counterpart of PDFBox's COSStandardOutputStream that keeps track
/// of the current write position and newline state while forwarding writes to a
/// [RandomAccessWrite] sink.
class COSStandardOutputStream {
  COSStandardOutputStream(this._output, [int position = 0])
      : _position = position;

  static final Uint8List crlf = Uint8List.fromList(<int>[0x0d, 0x0a]);
  static final Uint8List lf = Uint8List.fromList(<int>[0x0a]);
  static final Uint8List eol = lf;

  final RandomAccessWrite _output;
  int _position;
  bool _onNewLine = false;

  int get position => _position;

  bool get isOnNewLine => _onNewLine;

  set isOnNewLine(bool value) => _onNewLine = value;

  void reset({required int position, bool onNewLine = false}) {
    _position = position;
    _onNewLine = onNewLine;
  }

  void writeBytes(Uint8List data, [int offset = 0, int? length]) {
    final int safeLength = length ?? (data.length - offset);
    if (safeLength <= 0) {
      return;
    }
    _output.writeBytes(data, offset, safeLength);
    _position += safeLength;
    _onNewLine = false;
  }

  void writeByte(int value) {
    _output.writeByte(value & 0xff);
    _position += 1;
    _onNewLine = false;
  }

  void writeCRLF() => writeBytes(crlf);

  void writeEOL() {
    if (!_onNewLine) {
      writeBytes(eol);
      _onNewLine = true;
    }
  }

  void writeLF() => writeBytes(lf);
}
