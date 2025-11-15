import 'dart:async';
import 'dart:typed_data';

/// Minimal RC4 stream cipher used by the legacy PDF encryption handlers.
class RC4Cipher {
  RC4Cipher();

  final List<int> _salt = List<int>.filled(256, 0);
  int _b = 0;
  int _c = 0;

  /// Configures the RC4 key. The key length must be between 1 and 32 bytes.
  void setKey(List<int> key) {
    final length = key.length;
    if (length < 1 || length > 32) {
      throw ArgumentError.value(
        length,
        'length',
        'RC4 key length must be between 1 and 32 bytes',
      );
    }

    _b = 0;
    _c = 0;

    for (var i = 0; i < _salt.length; i++) {
      _salt[i] = i;
    }

    var keyIndex = 0;
    var saltIndex = 0;
    for (var i = 0; i < _salt.length; i++) {
      saltIndex = (_fixByte(key[keyIndex]) + _salt[i] + saltIndex) & 0xff;
      _swap(_salt, i, saltIndex);
      keyIndex = (keyIndex + 1) % length;
    }
  }

  /// Encrypts or decrypts [data], returning a new buffer with the result.
  Uint8List process(List<int> data) {
    final buffer = Uint8List(data.length);
    processInto(data, buffer, 0);
    return buffer;
  }

  /// Encrypts or decrypts [data], writing the bytes into [buffer] starting at [offset].
  void processInto(List<int> data, Uint8List buffer, int offset) {
    for (var i = 0; i < data.length; i++) {
      buffer[offset + i] = _encryptByte(data[i]);
    }
  }

  /// Convenience helper that processes chunks from [stream] and emits encrypted data to [sink].
  Future<void> processStream(
      Stream<List<int>> stream, void Function(Uint8List chunk) sink) async {
    await for (final chunk in stream) {
      sink(process(chunk));
    }
  }

  int _encryptByte(int value) {
    _b = (_b + 1) & 0xff;
    _c = (_salt[_b] + _c) & 0xff;
    _swap(_salt, _b, _c);
    final idx = (_salt[_b] + _salt[_c]) & 0xff;
    return (value ^ _salt[idx]) & 0xff;
  }

  static int _fixByte(int value) => value & 0xff;

  static void _swap(List<int> data, int first, int second) {
    final tmp = data[first];
    data[first] = data[second];
    data[second] = tmp;
  }
}
