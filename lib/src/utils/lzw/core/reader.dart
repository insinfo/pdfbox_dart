

part of lzw_core;

/**
 * LZW reader.
 */
abstract class LzwReader {
  late int codeLen;

  late Iterator<int> _iterator;

  int _bitLength = 0;

  int _tail = 0;

  int _tailLen = 0;

  void setInput(Iterator<int> iterator, int length) {
    _iterator = iterator;
    _bitLength = length * 8;
  }

  bool get hasData => (_bitLength + _tailLen) >= codeLen;

  int read() {
    _bitLength -= 8;
    _iterator.moveNext();
    return _iterator.current;
  }

  void flush();
}

/**
 * Reader that use the "Least Significant Bit first" packing order.
 *
 * Example: 87654321 xxxxCBA9
 */
class LsbReader extends LzwReader {

  int read() {
    for (; _tailLen < codeLen; _tailLen += 8) {
      _tail |= super.read() << _tailLen;
    }

    _tailLen -= codeLen;
    var code = _tail & ((1 << codeLen) - 1);
    _tail >>= codeLen;

    return code;
  }

  void flush() {
    for (; _bitLength > 0; _tailLen += 8) {
      _tail |= super.read() << _tailLen;
    }
  }
}

/**
 * Reader that use the "Most Significant Bit first" packing order.
 *
 * Example: CBA98765 4321xxxx
 */
class MsbReader extends LzwReader {

  int read() {
    for (; _tailLen < codeLen; _tailLen += 8) {
      _tail = (_tail << 8) | super.read();
    }

    _tailLen -= codeLen;
    var code = _tail >> _tailLen;
    _tail &= (1 << _tailLen) - 1;

    return code;
  }

  void flush() {
    for (; _bitLength > 0; _tailLen += 8) {
      _tail = (_tail << 8) | super.read();
    }
  }
}
