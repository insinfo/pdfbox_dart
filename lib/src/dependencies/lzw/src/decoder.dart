

part of lzw_core;

/**
 * [Converter] for decoding LZW compressed data.
 */
class LzwDecoder extends LzwConverter {
  final LzwOptions _options;

  /// Dictionary code:key, where key = (previous code << 8) | current symbol.
  final Map<int, int> _dictionary = new HashMap<int, int>();

  /// Symbols are stored here.
  final ByteBuffer _buffer = new ByteBuffer();

  /// Codes are read from here.
  late final LzwReader _reader;

  /// Next code to be added to the dictionary.
  late int _nextCode;

  /// Maximum code allowed for the current code length.
  late int _maxCode;

  /// "Clear Table" code.
  int? _clear;

  /// "End of Data" code.
  int? _eod;

  /// Previous key.
  int? _prevKey;

  LzwDecoder(this._options) {
    _reader = _options.lsb ? new LsbReader() : new MsbReader();

    _clearTable();

    // Calculate the "Clear Table" code.
    if (_options.blockMode) {
      _clear = 1 << (_options.minCodeLen - 1);
    }

    // Calculate the "End Of Data" code.
    if (_options.end) {
      var eod = 1 << (_options.minCodeLen - 1);
      if (_options.blockMode) {
        eod++;
      }
      _eod = eod;
    }
  }

  List<int> convert(List<int> chunk) => _convert(chunk.iterator, chunk.length);

  List<int> convertSlice(List<int> chunk, int start, int end, bool isLast)
    => _convert(chunk.getRange(start, end).iterator, end - start, isLast);

  /*
   * Decode.
   */
  List<int> _convert(Iterator<int> codes, int length, [bool isLast = false]) {
    final stack = <int>[];

    _reader.setInput(codes, length);

    while(_reader.hasData) {
      var code = _reader.read();

      // Clear Table?
      if (_clear != null && code == _clear) {
        _clearTable();
        _prevKey = null;
        continue;
      }

      // End Of Data?
      if (_eod != null && code == _eod) break;

      // Corrupt input?
      if (code > _nextCode) throw new StateError("Unexpected code ($code)");

      // Get the key (aka sequence of symbols) for the current code...
      final dictEntry = _dictionary[code];
      int key;

      // ... or use the key calculated in the previous iteration.
      if (dictEntry == null) {
        var prev = _prevKey;
        if (prev == null) {
          throw new StateError("Corrupted LZW stream: missing previous key");
        }
        key = prev;
        _dictionary[code] = key; // previous + previous[0]
      } else {
        key = dictEntry;
      }

      // Get the current symbol and write it to the output buffer.
      var symbol = key & 0xff;
      if ((key >> 8) == 0) {
        _buffer.write(symbol);
      } else {

        // Sequences of symbols are written using a stack.
        var chainKey = key;
        do {
          stack.add(symbol);
          var nextKey = _dictionary[(chainKey >> 8) - 1];
          if (nextKey == null) {
            throw new StateError("Corrupted LZW stream: missing dictionary entry");
          }
          chainKey = nextKey;
          symbol = chainKey & 0xff;
        } while((chainKey >> 8) != 0);

        stack
          ..add(symbol)
          ..reversed.forEach(_buffer.write)
          ..clear();
      }

      // Add the new entry to the dictionary: (previous code << 8) | current symbol.
      var prevKey = _prevKey;
      if (prevKey != null) {
        _dictionary[_nextCode ++] = (((prevKey >> 8) << 8) | symbol);
      }

      // Calculate the key for the next iteration: (current code << 8) | current symbol.
      _prevKey = ((code + 1) << 8) | symbol;

      // Check limits.
      if (_nextCode == _maxCode) {
        if (_reader.codeLen < _options.maxCodeLen) {

          // Increase the code lenght.
          _reader.codeLen ++;

          // Calculate the maximum code allowed for the new code length.
          _maxCode = 1 << _reader.codeLen;
          if (_options.earlyChange) _maxCode --;
        }
      }
    }

    _reader.flush();

    return _buffer.takeBytes();
  }

  List<int> flush() => const [];

  /**
   * Clear the dictionary.
   */
  void _clearTable() {
    _dictionary.clear();

    // Initialize the first entries in the dictionary.
    for (var i = (1 << (_options.minCodeLen - 1)) - 1; i >= 0; -- i) {
      _dictionary[i] = i;
    }

    // Set the initial code length.
    _reader.codeLen = _options.minCodeLen;

    // Calculate the next code to be added to the dictionary.
    _nextCode = 1 << (_options.minCodeLen - 1);
    if (_options.blockMode) _nextCode ++;
    if (_options.end) _nextCode ++;

    // Calculate the maximum code allowed for the current code length.
    _maxCode = 1 << _options.minCodeLen;
    if (_options.earlyChange) _maxCode --;
  }
}
