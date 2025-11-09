import 'dart:typed_data';

import '../../../fontbox/ttf/os2_windows_metrics_table.dart';
import '../../../fontbox/ttf/true_type_font.dart';
import '../../../fontbox/ttf/ttf_subsetter.dart';

/// Result produced after subsetting a TrueType font.
class TrueTypeSubsetResult {
  TrueTypeSubsetResult({
    required this.tag,
    required this.fontData,
    required Map<int, int> newToOldGlyphId,
  }) :
        newToOldGlyphId = Map<int, int>.unmodifiable(newToOldGlyphId),
        oldToNewGlyphId = Map<int, int>.unmodifiable(
          newToOldGlyphId.map((newId, oldId) => MapEntry(oldId, newId)),
        );

  /// Deterministic 6-character tag appended with +, e.g. `ABCDEZ+`.
  final String tag;

  /// Raw bytes of the subset font as a complete sfnt file.
  final Uint8List fontData;

  /// Mapping from subset glyph ids (new) back to the original glyph ids.
  final Map<int, int> newToOldGlyphId;

  /// Mapping from original glyph ids to the glyph ids used in the subset.
  final Map<int, int> oldToNewGlyphId;
}

/// Common functionality for embedding TrueType fonts with deterministic subsets.
class TrueTypeEmbedder {
  TrueTypeEmbedder(
    this._ttf, {
    bool embedSubset = true,
    List<String>? tablesToKeep,
  })  : _embedSubset = embedSubset,
        _subsetter = TtfSubsetter(_ttf, tablesToKeep ?? _defaultTables);

  static const List<String> _defaultTables = <String>[
    'head',
    'hhea',
    'loca',
    'maxp',
    'name',
    'cvt ',
    'prep',
    'glyf',
    'hmtx',
    'fpgm',
    'gasp',
  ];

  static const List<int> _forcedInvisibleCodePoints = <int>[
    0x200B, // zero width space
    0x200C, // zero width non-joiner
    0x2060, // word joiner
    0xFEFF, // zero width no-break space
  ];

  final TrueTypeFont _ttf;
  final bool _embedSubset;
  final TtfSubsetter _subsetter;

  bool _subsetWritten = false;

  /// Adds a Unicode code point that must be retained when the font is subset.
  void addToSubset(int codePoint) {
    if (!_embedSubset) {
      return;
    }
    _subsetter.add(codePoint);
  }

  /// Adds glyph ids that must be retained even if they are not reachable via cmap lookups.
  void addGlyphIds(Iterable<int> glyphIds) {
    if (!_embedSubset) {
      return;
    }
    _subsetter.addGlyphIds(glyphIds);
  }

  /// Returns true if a subset needs to be produced instead of a full embedding.
  bool get needsSubset => _embedSubset;

  /// Builds a subset of the current TrueType font and returns the resulting data.
  TrueTypeSubsetResult subset() {
    if (_subsetWritten) {
      throw StateError('Subset has already been produced for this embedder instance');
    }
    _subsetWritten = true;

    if (!_embedSubset) {
      throw StateError('Subsetting is disabled for this embedder instance');
    }

    if (!_isSubsettingPermitted(_ttf)) {
      throw StateError('This font does not permit subsetting');
    }

    for (final codePoint in _forcedInvisibleCodePoints) {
      _subsetter.forceInvisible(codePoint);
    }

    final gidMap = _subsetter.getGidMap();
    final tag = _computeTag(gidMap);
    _subsetter.setPrefix(tag);
    final subsetBytes = _subsetter.buildSubset();

    return TrueTypeSubsetResult(
      tag: tag,
      fontData: subsetBytes,
      newToOldGlyphId: gidMap,
    );
  }

  bool _isSubsettingPermitted(TrueTypeFont font) {
    final os2 = font.getOs2WindowsMetricsTable();
    if (os2 == null) {
      return true;
    }
    final fsType = os2.fsType;
    if ((fsType & Os2WindowsMetricsTable.fsTypeNoSubsetting) != 0) {
      return false;
    }
    return true;
  }

  String _computeTag(Map<int, int> gidMap) {
    var hash = 0;
    gidMap.forEach((newId, oldId) {
      hash = (hash + (newId ^ oldId)) & 0xFFFFFFFF;
    });

    var num = hash & 0xFFFFFFFF;
    final buffer = StringBuffer();
    do {
      final div = num ~/ 25;
      final mod = num % 25;
      buffer.write(_base25[mod]);
      num = div;
    } while (num != 0 && buffer.length < 6);

    while (buffer.length < 6) {
      buffer.write('A');
    }

    final tag = buffer.toString().split('').reversed.join();
    return '$tag+';
  }

  static const String _base25 = 'BCDEFGHIJKLMNOPQRSTUVWXYZ';
}
