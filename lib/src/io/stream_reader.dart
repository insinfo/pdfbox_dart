/// Simple byte reader over an in-memory buffer.
class PdfStreamReader {
  PdfStreamReader([this.data]) : _position = 0;

  /// Backing data buffer.
  List<int>? data;

  int _position;

  /// Total length of the buffer.
  int? get length => data?.length;

  /// Current read position.
  int get position => _position;
  set position(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'position', 'Invalid position');
    }
    _position = value;
  }

  /// Reads a single byte, or -1 on EOF.
  int? readByte() {
    final int? len = length;
    if (len != null && _position < len) {
      final int result = data![_position];
      _position += 1;
      return result;
    }
    return -1;
  }

  /// Reads up to [length] bytes into [buffer] starting at [offset].
  int? read(List<int> buffer, int offset, int length) {
    _position = offset;
    int pos = offset;
    final int end = _position + length;
    while (_position < end) {
      final int byte = readByte()!;
      if (byte == -1) {
        break;
      }
      buffer[pos++] = byte;
    }
    return pos - offset;
  }
}

