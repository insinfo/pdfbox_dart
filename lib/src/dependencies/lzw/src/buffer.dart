

part of lzw_core;

/**
 * Growable list of bytes.
 */
class ByteBuffer {
  static const int INITIAL_SIZE = 4096;

  Uint8List? _bytes;

  int _length = 0;

  void write(int byte) {
    _ensureCapacity();

  _bytes![_length ++] = byte;
  }

  List<int> takeBytes() {
    _ensureCapacity();

    var view = new Uint8List.view(_bytes!.buffer, 0, _length);
    _bytes = null;
    _length = 0;
    return view;
  }

  void _ensureCapacity() {
    if (_bytes == null) {
      _bytes = new Uint8List(INITIAL_SIZE);
      _length = 0;
    }
    if (_length == _bytes!.length) {
      var len = _bytes!.length + (_bytes!.length >> 1);
      var newBytes = new Uint8List(len);
      newBytes.setAll(0, _bytes!);
      _bytes = newBytes;
    }
  }
}
