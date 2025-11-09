import 'dart:typed_data';

import '../../io/random_access_read_buffer.dart';
import '../cmap/cmap.dart';
import 'cff_font.dart';
import 'char_string_path.dart';

/// Bridges PDF CMap code units to glyph data in a CID-keyed CFF font.
class CidGlyphMapper {
  CidGlyphMapper(this._font, this._cmap, {int notdefCid = 0})
      : _notdefCid = notdefCid;

  final CFFCIDFont _font;
  final CMap _cmap;
  final int _notdefCid;

  /// Resolves the CID associated with the encoded [code].
  int toCid(Uint8List code) {
    if (!_cmap.hasCIDMappings()) {
      return _notdefCid;
    }
    return _normaliseCid(_cmap.toCID(code));
  }

  /// Resolves the CID from an integer [code] and optional explicit [length].
  int toCidFromInt(int code, {int? length}) {
    if (!_cmap.hasCIDMappings()) {
      return _notdefCid;
    }
    final cid =
        length != null ? _cmap.toCIDWithLength(code, length) : _cmap.toCIDFromInt(code);
    return _normaliseCid(cid);
  }

  /// Resolves the GID for the encoded [code].
  int toGid(Uint8List code) => _font.charset.getGIDForCID(toCid(code));

  /// Resolves the GID associated with [cid].
  int toGidFromCid(int cid) => _font.charset.getGIDForCID(_normaliseCid(cid));

  /// Returns the outline path for the glyph mapped from [code].
  CharStringPath getPath(Uint8List code) => _font.getPathForCID(toCid(code));

  /// Returns the advance width for the glyph mapped from [code].
  double getWidth(Uint8List code) => _font.getWidthForCID(toCid(code));

  /// Returns `true` when the encoded [code] resolves to an available glyph.
  bool hasGlyph(Uint8List code) => toGid(code) != 0;

  /// Decodes an encoded string [input] into CID/GID mappings.
  List<CidGlyphMapping> mapEncoded(Uint8List input) {
    if (input.isEmpty) {
      return const <CidGlyphMapping>[];
    }

    final reader = RandomAccessReadBuffer.fromBytes(input);
    final result = <CidGlyphMapping>[];

    try {
      while (true) {
        final start = reader.position;
        final code = _cmap.readCode(reader);
        if (code == -1) {
          break;
        }
        final end = reader.position;
        final length = end - start;
        if (length <= 0) {
          if (reader.position >= input.length) {
            break;
          }
          continue;
        }

        final cid = toCidFromInt(code, length: length);
        final normalisedCid = _normaliseCid(cid);
        final gid = _font.charset.getGIDForCID(normalisedCid);
        final width = _font.getWidthForCID(normalisedCid);
        final codeUnits = Uint8List.fromList(input.sublist(start, end));

        result.add(CidGlyphMapping(codeUnits, normalisedCid, gid, width));
      }
    } finally {
      reader.close();
    }

    return result.isEmpty
        ? const <CidGlyphMapping>[]
        : List<CidGlyphMapping>.unmodifiable(result);
  }

  /// Convenience for decoding [input] directly into CID values.
  List<int> decodeToCids(Uint8List input) =>
      mapEncoded(input).map((mapping) => mapping.cid).toList(growable: false);

  /// Convenience for decoding [input] directly into glyph ids.
  List<int> decodeToGids(Uint8List input) =>
      mapEncoded(input).map((mapping) => mapping.gid).toList(growable: false);

  /// Convenience for decoding [input] directly into advance widths.
  List<double> decodeToWidths(Uint8List input) =>
      mapEncoded(input).map((mapping) => mapping.width).toList(growable: false);
  int _normaliseCid(int cid) => cid <= 0 ? _notdefCid : cid;
}

/// Represents a decoded mapping between encoded bytes, CIDs and glyph IDs.
class CidGlyphMapping {
  CidGlyphMapping(this.codeUnits, this.cid, this.gid, this.width);

  final Uint8List codeUnits;
  final int cid;
  final int gid;
  final double width;

  bool get isNotdef => cid == 0 || gid == 0;
}
