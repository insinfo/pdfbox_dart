

part of lzw_core;

/**
 * LZW writer.
 */
abstract class LzwWriter extends ByteBuffer {
  late int codeLen;

  int _tail = 0;

  int _tailLen = 0;

  void flush();
}

/**
 * Writer that use the "Least Significant Bit first" packing order.
 *
 * Example: 87654321 xxxxCBA9
 */
class LsbWriter extends LzwWriter {

  void write(int code) {
    _tail |= code << _tailLen;
    _tailLen += codeLen;
    while(_tailLen >= 8) {
      _tailLen -= 8;
      super.write(_tail & 0xff);
      _tail >>= 8;
    }
  }

  void flush() {
    if (_tailLen != 0) {
      super.write(_tail);
      _tail = 0;
      _tailLen = 0;
    }
  }
}

/**
 * Writer that use the "Most Significant Bit first" packing order.
 *
 * Example: CBA98765 4321xxxx
 */
class MsbWriter extends LzwWriter {

  void write(int code) {
    _tail = (_tail << codeLen) | code;
    _tailLen += codeLen;
    while(_tailLen >= 8) {
      _tailLen -= 8;
      super.write(_tail >> _tailLen);
      _tail &= (1 << _tailLen) - 1;
    }
  }

  void flush() {
    if (_tailLen != 0) {
      super.write(_tail << (8 - _tailLen));
      _tail = 0;
      _tailLen = 0;
    }
  }
}
