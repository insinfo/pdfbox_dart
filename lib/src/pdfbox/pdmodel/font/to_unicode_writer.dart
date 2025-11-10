import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

/// Writes a minimal ToUnicode CMap for a font.
class ToUnicodeWriter {
  ToUnicodeWriter({int wMode = 0}) : _wMode = wMode;

  /// Maximum number of entries per `beginbfrange` operator.
  static const int maxEntriesPerOperator = 100;

  final SplayTreeMap<int, String> _cidToUnicode = SplayTreeMap<int, String>();
  int _wMode;

  bool get hasMappings => _cidToUnicode.isNotEmpty;

  /// Sets the writing mode. Use 1 for vertical fonts, 0 otherwise.
  set wMode(int value) {
    _wMode = value;
  }

  /// Adds a CID to Unicode mapping.
  void add(int cid, String text) {
    if (cid < 0 || cid > 0xFFFF) {
      throw ArgumentError.value(cid, 'cid', 'CID must be between 0x0000 and 0xFFFF');
    }
    if (text.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Unicode mapping must not be empty');
    }
    _cidToUnicode[cid] = text;
  }

  /// Serialises the CMap into ASCII bytes ready to be used in a stream.
  Uint8List toBytes() {
    final buffer = StringBuffer();

    void writeln([String text = '']) {
      buffer.write(text);
      buffer.write('\n');
    }

    writeln('/CIDInit /ProcSet findresource begin');
    writeln('12 dict begin');
    writeln();
    writeln('begincmap');
    writeln('/CIDSystemInfo');
    writeln('<< /Registry (Adobe)');
    writeln('/Ordering (UCS)');
    writeln('/Supplement 0');
    writeln('>> def');
    writeln();
    writeln('/CMapName /Adobe-Identity-UCS def');
    writeln('/CMapType 2 def');
    writeln();

    if (_wMode != 0) {
      writeln('/WMode /$_wMode def');
      writeln();
    }

    writeln('1 begincodespacerange');
    writeln('<0000> <FFFF>');
    writeln('endcodespacerange');
    writeln();

    final srcFrom = <int>[];
    final srcTo = <int>[];
    final dst = <String>[];

    MapEntry<int, String>? previous;
    for (final entry in _cidToUnicode.entries) {
      if (allowCidToUnicodeRange(previous, entry)) {
        srcTo[srcTo.length - 1] = entry.key;
      } else {
        srcFrom.add(entry.key);
        srcTo.add(entry.key);
        dst.add(entry.value);
      }
      previous = entry;
    }

    const maxEntries = maxEntriesPerOperator;
    final totalEntries = srcFrom.length;
    final batchCount = totalEntries == 0 ? 0 : (totalEntries + maxEntries - 1) ~/ maxEntries;

    for (var batch = 0; batch < batchCount; batch++) {
      final start = batch * maxEntries;
      final end = (start + maxEntries) < totalEntries ? start + maxEntries : totalEntries;
      final count = end - start;
      buffer.write('$count beginbfrange\n');
      for (var index = start; index < end; index++) {
        final from = srcFrom[index];
        final to = srcTo[index];
        final unicode = dst[index];
        buffer
          ..write('<')
          ..write(_hex16(from))
          ..write('> <')
          ..write(_hex16(to))
          ..write('> <')
          ..write(_hexUtf16Be(unicode))
          ..write('>\n');
      }
      writeln('endbfrange');
      writeln();
    }

    writeln('endcmap');
    writeln('CMapName currentdict /CMap defineresource pop');
    writeln('end');
    writeln('end');

    return Uint8List.fromList(ascii.encode(buffer.toString()));
  }

  /// Returns true if the destination range can be merged according to the spec.
  static bool allowCidToUnicodeRange(
    MapEntry<int, String>? previous,
    MapEntry<int, String>? next,
  ) {
    if (previous == null || next == null) {
      return false;
    }
    return allowCodeRange(previous.key, next.key) &&
        allowDestinationRange(previous.value, next.value);
  }

  /// Returns true if the two codes differ only in their low byte and are sequential.
  static bool allowCodeRange(int previous, int next) {
    if (previous + 1 != next) {
      return false;
    }
    final prevHigh = (previous >> 8) & 0xFF;
    final prevLow = previous & 0xFF;
    final nextHigh = (next >> 8) & 0xFF;
    final nextLow = next & 0xFF;
    return prevHigh == nextHigh && prevLow < nextLow;
  }

  /// Returns true if the Unicode destinations are sequential and share the same high byte.
  static bool allowDestinationRange(String previous, String next) {
    if (previous.isEmpty || next.isEmpty) {
      return false;
    }
    final prevCodePoint = previous.runes.first;
    final nextCodePoint = next.runes.first;
    if (!allowCodeRange(prevCodePoint, nextCodePoint)) {
      return false;
    }
    return previous.runes.length == 1;
  }

  static String _hex16(int value) => value.toRadixString(16).padLeft(4, '0').toUpperCase();

  static String _hexUtf16Be(String text) {
    final buffer = StringBuffer();
    for (final codePoint in text.runes) {
      if (codePoint >= 0x10000) {
        final base = codePoint - 0x10000;
        final high = 0xD800 + (base >> 10);
        final low = 0xDC00 + (base & 0x3FF);
        buffer..write(_hex16(high))..write(_hex16(low));
      } else {
        buffer.write(_hex16(codePoint));
      }
    }
    return buffer.toString();
  }
}
