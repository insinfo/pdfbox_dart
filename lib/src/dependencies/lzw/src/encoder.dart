

part of lzw_core;

/**
 * [Converter] for encoding to LZW compressed data.
 */
class LzwEncoder extends LzwConverter {
  final LzwOptions _options;

  /// Dictionary key:code, where key = (previous code << 8) | symbol.
  final Map<int, int> _dictionary = new HashMap<int, int>();

  /// Codes are written here.
  late final LzwWriter _writer;

  /// Current code.
  int? _code;

  /// Next code to be added to the dictionary.
  late int _nextCode;

  /// Maximum code allowed for the current code length.
  late int _maxCode;

  LzwEncoder(this._options) {
    _writer = _options.lsb ? new LsbWriter() : new MsbWriter();
  }

  List<int> convert(List<int> chunk) => _convert(chunk.iterator);

  List<int> convertSlice(List<int> chunk, int start, int end, bool isLast)
    => _convert(chunk.getRange(start, end).iterator, isLast);

  /**
   * Encode.
   */
  List<int> _convert(Iterator<int> symbols, [bool isLast = false]) {

    // Only for the first chunk of symbols.
    if (_code == null) {
      _clearTable();

      // Write a "Clear Table" code.
      if (_options.clear) _writer.write(1 << (_options.minCodeLen - 1));

      // Get the first code/symbol.
      if (!symbols.moveNext()) {
        return _writer.takeBytes();
      }
      _code = symbols.current;
    }

    while(symbols.moveNext()) {
      final previousCode = _code!;

      // Calculate the key: (previous code << 8) | current symbol.
      var key = (previousCode << 8) | symbols.current;

      // Get the code from the dictionary for the key (aka sequence of symbols).
      _code = _dictionary[key];

      // If the key is not in the dictionary yet then add it, otherwise continue.
      if (_code == null) {
        _dictionary[key] = _nextCode ++;

        // Emit the previous code/symbol.
        _writer.write(key >> 8);

        // Start a new sequence with the current symbol.
        _code = key & 0xff;

        // Check limits.
        if (_nextCode == _maxCode) {
          if (_writer.codeLen == _options.maxCodeLen) {

            // Write a "Clear Table" code.
            if (_options.blockMode) _writer.write(1 << (_options.minCodeLen - 1));

            _clearTable();
          } else {

            // Increase the code lenght.
            _writer.codeLen ++;

           // Calculate the maximum code allowed for the new code length.
            _maxCode = 1 << _writer.codeLen;
            if (_writer.codeLen < _options.maxCodeLen) _maxCode ++;
            if (_options.earlyChange) _maxCode --;
          }
        }
      }
    }

    return isLast ? flush() : _writer.takeBytes();
  }

  /**
   * Ensure that all the codes are written.
   */
  List<int> flush() {
    if (_code != null) _writer.write(_code!);

    // Write a "End Of Data" code.
    if (_options.end) {
      var eod = 1 << (_options.minCodeLen - 1);
      if (_options.blockMode) eod ++;
      _writer.write(eod);
    }

    _writer.flush();

    return _writer.takeBytes();
  }

  /**
   * Clear the dictionary.
   */
  void _clearTable() {
    _dictionary.clear();

    // Set the initial code length.
    _writer.codeLen = _options.minCodeLen;

    // Calculate the next code to be added to the dictionary.
    _nextCode = 1 << (_options.minCodeLen - 1);
    if (_options.blockMode) _nextCode ++;
    if (_options.end) _nextCode ++;

    // Calculate the maximum code allowed for the current code length.
    _maxCode = 1 << _options.minCodeLen;
    if (_options.minCodeLen < _options.maxCodeLen) _maxCode ++;
    if (_options.earlyChange) _maxCode --;
  }
}
