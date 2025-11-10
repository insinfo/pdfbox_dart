import 'dart:collection';
import 'dart:typed_data';

import '../../../fontbox/ttf/cmap_lookup.dart';
import '../../../fontbox/ttf/glyph_data.dart';
import '../../../fontbox/ttf/glyph_table.dart';
import '../../../fontbox/ttf/horizontal_metrics_table.dart';
import '../../../fontbox/ttf/true_type_font.dart';
import '../../../fontbox/ttf/vertical_header_table.dart';
import '../../../fontbox/ttf/vertical_metrics_table.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_integer.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_stream.dart';
import '../pd_stream.dart';
import 'pd_font_descriptor.dart';
import 'to_unicode_writer.dart';
import 'true_type_embedder.dart';
import 'true_type_font_descriptor_builder.dart';

enum _CompressionState { first, bracket, serial }

/// Result of building a CIDFontType2 embedder.
class PDCIDFontType2EmbedderResult {
  PDCIDFontType2EmbedderResult({
    required this.type0Dictionary,
    required this.cidFontDictionary,
    required this.fontDescriptor,
    required this.isSubset,
    this.subset,
    required this.cidToGidMap,
  });

  /// Type 0 font dictionary containing encoding and descendant font.
  final COSDictionary type0Dictionary;

  /// Descendant CIDFont dictionary for the embedded subset.
  final COSDictionary cidFontDictionary;

  /// Font descriptor populated with metrics and embedded font stream.
  final PDFontDescriptor fontDescriptor;

  /// Indicates whether the embedded font was subset.
  final bool isSubset;

  /// Subset information returned by the TrueType embedder, when available.
  final TrueTypeSubsetResult? subset;

  /// Mapping from original CIDs (old GIDs) to subset GIDs.
  final Map<int, int> cidToGidMap;
}

/// Helper for embedding CIDFontType2 (TrueType) fonts inside Type 0 wrappers.
class PDCIDFontType2Embedder {
  PDCIDFontType2Embedder({
    required TrueTypeFont trueTypeFont,
    bool embedSubset = true,
    bool vertical = false,
  })  : _ttf = trueTypeFont,
        _embedSubset = embedSubset,
        _vertical = vertical,
        _embedder = TrueTypeEmbedder(trueTypeFont, embedSubset: embedSubset),
  _unicodeCmap = trueTypeFont.getUnicodeCmapLookup(isStrict: false),
    _unitsPerEmScale = _computeUnitsPerEmScale(trueTypeFont),
    _basePostScriptName = _resolvePostScriptName(trueTypeFont);

  final TrueTypeFont _ttf;
  final bool _embedSubset;
  final bool _vertical;
  final TrueTypeEmbedder _embedder;
  final CMapLookup? _unicodeCmap;
  final double _unitsPerEmScale;
  final String _basePostScriptName;

  /// Adds a Unicode [codePoint] to the pending subset.
  void addUnicode(int codePoint) => _embedder.addToSubset(codePoint);

  /// Adds multiple Unicode code points to the pending subset.
  void addUnicodes(Iterable<int> codePoints) {
    for (final codePoint in codePoints) {
      _embedder.addToSubset(codePoint);
    }
  }

  /// Adds raw glyph ids that must be present in the subset.
  void addGlyphIds(Iterable<int> glyphIds) => _embedder.addGlyphIds(glyphIds);

  /// Indicates whether a subset is required for embedding.
  bool get needsSubset => _embedder.needsSubset;

  /// Builds the Type 0/CIDFont dictionaries and embeds the font subset.
  PDCIDFontType2EmbedderResult build() {
    if (_embedSubset) {
      return _buildSubsetFont();
    }
    return _buildFullFont();
  }

  PDCIDFontType2EmbedderResult _buildSubsetFont() {
    final subset = _embedder.subset();
    final subsetFontName = '${subset.tag}$_basePostScriptName';

    final defaultWidth = _scaledAdvanceWidth(0);
    final descriptor = TrueTypeFontDescriptorBuilder(
      font: _ttf,
      postScriptName: subsetFontName,
      missingWidth: defaultWidth,
    ).build();
    descriptor.fontName = subsetFontName;
    descriptor.setFontFile2Data(subset.fontData);

    final cidToGid = SplayTreeMap<int, int>();
    subset.newToOldGlyphId.forEach((newGid, oldGid) {
      cidToGid[oldGid] = newGid;
    });
    cidToGid.putIfAbsent(0, () => 0);

    final type0Dict = _createType0Dictionary(subsetFontName);
    final cidFontDict = _createSubsetCidFontDictionary(
      subsetFontName: subsetFontName,
      descriptor: descriptor,
      cidToGid: cidToGid,
      defaultWidth: defaultWidth,
    );

    final descendants = COSArray()..addObject(cidFontDict);
    type0Dict[COSName.descendantFonts] = descendants;

    _writeToUnicode(type0Dict, cidToGid.keys);

    return PDCIDFontType2EmbedderResult(
      type0Dictionary: type0Dict,
      cidFontDictionary: cidFontDict,
      fontDescriptor: descriptor,
      isSubset: true,
      subset: subset,
      cidToGidMap: Map<int, int>.unmodifiable(cidToGid),
    );
  }

  PDCIDFontType2EmbedderResult _buildFullFont() {
    final fontName = _basePostScriptName;
    final defaultWidth = _scaledAdvanceWidth(0);
    final descriptor = TrueTypeFontDescriptorBuilder(
      font: _ttf,
      postScriptName: fontName,
      missingWidth: defaultWidth,
    ).build();
    descriptor.fontName = fontName;
    descriptor.setFontFile2Data(_ttf.copyFontData());

    final type0Dict = _createType0Dictionary(fontName);
    final cidFontDict = _createFullCidFontDictionary(
      fontName: fontName,
      descriptor: descriptor,
      defaultWidth: defaultWidth,
    );

    final descendants = COSArray()..addObject(cidFontDict);
    type0Dict[COSName.descendantFonts] = descendants;

    _writeToUnicode(type0Dict, List<int>.generate(_ttf.numberOfGlyphs, (index) => index));

    return PDCIDFontType2EmbedderResult(
      type0Dictionary: type0Dict,
      cidFontDictionary: cidFontDict,
      fontDescriptor: descriptor,
      isSubset: false,
      subset: null,
      cidToGidMap: const <int, int>{},
    );
  }

  COSDictionary _createType0Dictionary(String fontName) {
    final dict = COSDictionary()
      ..setName(COSName.type, 'Font')
      ..setName(COSName.subtype, COSName.type0.name)
      ..setName(COSName.baseFont, fontName)
      ..setName(COSName.encoding, _vertical ? 'Identity-V' : 'Identity-H');
    if (_vertical) {
      dict.setInt(COSName.wMode, 1);
    }
    return dict;
  }

  COSDictionary _createSubsetCidFontDictionary({
    required String subsetFontName,
    required PDFontDescriptor descriptor,
    required SplayTreeMap<int, int> cidToGid,
    required double defaultWidth,
  }) {
    final dict = COSDictionary()
      ..setName(COSName.type, 'Font')
      ..setName(COSName.subtype, COSName.cidFontType2.name)
      ..setName(COSName.baseFont, subsetFontName)
      ..setItem(COSName.fontDescriptor, descriptor.cosObject)
      ..setItem(COSName.cidSystemInfo, _createCidSystemInfo());

    dict.setInt(COSName.dw, defaultWidth.round());

    final widthsArray = _buildWidthsArray(cidToGid, defaultWidth.round());
    if (widthsArray.length > 0) {
      dict[COSName.w] = widthsArray;
    }

    final cidToGidMapStream = _buildCidToGidMap(cidToGid);
    dict[COSName.cidToGidMap] = cidToGidMapStream;

    final cidSet = _buildCidSetFromCids(cidToGid.keys);
    descriptor.setCIDSetData(cidSet);

    if (_vertical) {
      _buildVerticalMetricsFromSubset(dict, cidToGid);
    }

    return dict;
  }

  COSDictionary _createFullCidFontDictionary({
    required String fontName,
    required PDFontDescriptor descriptor,
    required double defaultWidth,
  }) {
    final dict = COSDictionary()
      ..setName(COSName.type, 'Font')
      ..setName(COSName.subtype, COSName.cidFontType2.name)
      ..setName(COSName.baseFont, fontName)
      ..setItem(COSName.fontDescriptor, descriptor.cosObject)
      ..setItem(COSName.cidSystemInfo, _createCidSystemInfo());

    dict.setInt(COSName.dw, defaultWidth.round());

    final widthsArray = _buildFullWidthsArray();
    if (widthsArray.length > 0) {
      dict[COSName.w] = widthsArray;
    }

    dict[COSName.cidToGidMap] = COSName.identity;

    if (_vertical) {
      _buildVerticalMetricsForFull(dict);
    }

    return dict;
  }

  COSArray _buildFullWidthsArray() {
    final HorizontalMetricsTable? hmtx = _ttf.getHorizontalMetricsTable();
    if (hmtx == null) {
      return COSArray();
    }

    final glyphCount = _ttf.numberOfGlyphs;
    if (glyphCount <= 0) {
      return COSArray();
    }

    final data = List<int>.filled(glyphCount * 2, 0, growable: false);
    for (var cid = 0; cid < glyphCount; cid++) {
      data[cid * 2] = cid;
      data[cid * 2 + 1] = hmtx.getAdvanceWidth(cid);
    }

    return _compressWidthData(data);
  }

  COSArray _compressWidthData(List<int> widths) {
    if (widths.length < 2) {
      return COSArray();
    }

    final scale = _unitsPerEmScale == 0 ? 1.0 : _unitsPerEmScale;
    var lastCid = widths[0];
    var lastValue = (widths[1] * scale).round();

    final outer = COSArray()..addObject(COSInteger(lastCid));
    var inner = COSArray();
    var state = _CompressionState.first;

    for (var index = 2; index < widths.length - 1; index += 2) {
      final cid = widths[index];
      final value = (widths[index + 1] * scale).round();

      switch (state) {
        case _CompressionState.first:
          if (cid == lastCid + 1 && value == lastValue) {
            state = _CompressionState.serial;
          } else if (cid == lastCid + 1) {
            state = _CompressionState.bracket;
            inner = COSArray()..addObject(COSInteger(lastValue));
          } else {
            inner = COSArray()..addObject(COSInteger(lastValue));
            outer.addObject(inner);
            outer.addObject(COSInteger(cid));
          }
          break;
        case _CompressionState.bracket:
          if (cid == lastCid + 1 && value == lastValue) {
            state = _CompressionState.serial;
            outer.addObject(inner);
            outer.addObject(COSInteger(lastCid));
          } else if (cid == lastCid + 1) {
            inner.addObject(COSInteger(lastValue));
          } else {
            state = _CompressionState.first;
            inner.addObject(COSInteger(lastValue));
            outer.addObject(inner);
            outer.addObject(COSInteger(cid));
          }
          break;
        case _CompressionState.serial:
          if (cid != lastCid + 1 || value != lastValue) {
            outer
              ..addObject(COSInteger(lastCid))
              ..addObject(COSInteger(lastValue))
              ..addObject(COSInteger(cid));
            state = _CompressionState.first;
          }
          break;
      }

      lastValue = value;
      lastCid = cid;
    }

    switch (state) {
      case _CompressionState.first:
        inner = COSArray()..addObject(COSInteger(lastValue));
        outer.addObject(inner);
        break;
      case _CompressionState.bracket:
        inner.addObject(COSInteger(lastValue));
        outer.addObject(inner);
        break;
      case _CompressionState.serial:
        outer
          ..addObject(COSInteger(lastCid))
          ..addObject(COSInteger(lastValue));
        break;
    }

    return outer;
  }

  void _buildVerticalMetricsForFull(COSDictionary cidFont) {
    if (!_buildVerticalHeader(cidFont)) {
      return;
    }

    final GlyphTable? glyf = _ttf.getGlyphTable();
    final VerticalMetricsTable? vmtx = _ttf.getVerticalMetricsTable();
    final HorizontalMetricsTable? hmtx = _ttf.getHorizontalMetricsTable();
    if (glyf == null || vmtx == null || hmtx == null) {
      return;
    }

    final glyphCount = _ttf.numberOfGlyphs;
    if (glyphCount <= 0) {
      return;
    }

    const int sentinel = -0x80000000;
    final data = List<int>.filled(glyphCount * 4, 0, growable: false);
    for (var cid = 0; cid < glyphCount; cid++) {
      final glyph = glyf.getGlyph(cid);
      if (glyph == null) {
        data[cid * 4] = sentinel;
        continue;
      }
      data[cid * 4] = cid;
      data[cid * 4 + 1] = vmtx.getAdvanceHeight(cid);
      data[cid * 4 + 2] = hmtx.getAdvanceWidth(cid);
      data[cid * 4 + 3] = glyph.getYMaximum() + vmtx.getTopSideBearing(cid);
    }

    final metrics = _compressVerticalMetricData(data, sentinel);
    if (metrics.length > 0) {
      cidFont[COSName.w2] = metrics;
    }
  }

  COSArray _compressVerticalMetricData(List<int> values, int sentinel) {
    if (values.length < 4) {
      return COSArray();
    }

    final scale = _unitsPerEmScale == 0 ? 1.0 : _unitsPerEmScale;

    var offset = 0;
    while (offset <= values.length - 4 && values[offset] == sentinel) {
      offset += 4;
    }
    if (offset > values.length - 4) {
      return COSArray();
    }

    var lastCid = values[offset];
    var lastW1 = (-values[offset + 1] * scale).round();
    var lastVx = (values[offset + 2] * scale / 2).round();
    var lastVy = (values[offset + 3] * scale).round();

    final outer = COSArray()..addObject(COSInteger(lastCid));
    var inner = COSArray();
    var state = _CompressionState.first;

    for (var index = offset + 4; index < values.length - 3; index += 4) {
      final cid = values[index];
      if (cid == sentinel) {
        continue;
      }

      final w1Value = (-values[index + 1] * scale).round();
      final vxValue = (values[index + 2] * scale / 2).round();
      final vyValue = (values[index + 3] * scale).round();

      switch (state) {
        case _CompressionState.first:
          if (cid == lastCid + 1 &&
              w1Value == lastW1 &&
              vxValue == lastVx &&
              vyValue == lastVy) {
            state = _CompressionState.serial;
          } else if (cid == lastCid + 1) {
            state = _CompressionState.bracket;
            inner = COSArray()
              ..addObject(COSInteger(lastW1))
              ..addObject(COSInteger(lastVx))
              ..addObject(COSInteger(lastVy));
          } else {
            inner = COSArray()
              ..addObject(COSInteger(lastW1))
              ..addObject(COSInteger(lastVx))
              ..addObject(COSInteger(lastVy));
            outer.addObject(inner);
            outer.addObject(COSInteger(cid));
          }
          break;
        case _CompressionState.bracket:
          if (cid == lastCid + 1 &&
              w1Value == lastW1 &&
              vxValue == lastVx &&
              vyValue == lastVy) {
            state = _CompressionState.serial;
            outer.addObject(inner);
            outer.addObject(COSInteger(lastCid));
          } else if (cid == lastCid + 1) {
            inner
              ..addObject(COSInteger(lastW1))
              ..addObject(COSInteger(lastVx))
              ..addObject(COSInteger(lastVy));
          } else {
            state = _CompressionState.first;
            inner
              ..addObject(COSInteger(lastW1))
              ..addObject(COSInteger(lastVx))
              ..addObject(COSInteger(lastVy));
            outer.addObject(inner);
            outer.addObject(COSInteger(cid));
          }
          break;
        case _CompressionState.serial:
          if (cid != lastCid + 1 ||
              w1Value != lastW1 ||
              vxValue != lastVx ||
              vyValue != lastVy) {
            outer
              ..addObject(COSInteger(lastCid))
              ..addObject(COSInteger(lastW1))
              ..addObject(COSInteger(lastVx))
              ..addObject(COSInteger(lastVy))
              ..addObject(COSInteger(cid));
            state = _CompressionState.first;
          }
          break;
      }

      lastW1 = w1Value;
      lastVx = vxValue;
      lastVy = vyValue;
      lastCid = cid;
    }

    switch (state) {
      case _CompressionState.first:
        inner = COSArray()
          ..addObject(COSInteger(lastW1))
          ..addObject(COSInteger(lastVx))
          ..addObject(COSInteger(lastVy));
        outer.addObject(inner);
        break;
      case _CompressionState.bracket:
        inner
          ..addObject(COSInteger(lastW1))
          ..addObject(COSInteger(lastVx))
          ..addObject(COSInteger(lastVy));
        outer.addObject(inner);
        break;
      case _CompressionState.serial:
        outer
          ..addObject(COSInteger(lastCid))
          ..addObject(COSInteger(lastW1))
          ..addObject(COSInteger(lastVx))
          ..addObject(COSInteger(lastVy));
        break;
    }

    return outer;
  }

  COSDictionary _createCidSystemInfo() {
    final info = COSDictionary()
      ..setString(COSName.registry, 'Adobe')
      ..setString(COSName.ordering, 'Identity')
      ..setInt(COSName.supplement, 0);
    return info;
  }
  COSArray _buildWidthsArray(SplayTreeMap<int, int> cidToGid, int defaultWidth) {
    final widths = COSArray();
    if (cidToGid.isEmpty) {
      return widths;
    }

    COSArray? currentRange;
    var previousCid = -1;

    for (final entry in cidToGid.entries) {
      final cid = entry.key;
      final width = _scaledAdvanceWidth(cid).round();
      if (width == defaultWidth) {
        continue;
      }

      if (currentRange == null || cid != previousCid + 1) {
        currentRange = COSArray();
        widths.addObject(COSInteger(cid));
        widths.addObject(currentRange);
      }

      currentRange.addObject(COSInteger(width));
      previousCid = cid;
    }

    return widths;
  }

  COSStream _buildCidToGidMap(SplayTreeMap<int, int> cidToGid) {
    final lastCid = cidToGid.isEmpty ? 0 : cidToGid.keys.last;
    final buffer = Uint8List((lastCid + 1) * 2);
    final view = ByteData.sublistView(buffer);
    cidToGid.forEach((cid, gid) {
      view.setUint16(cid * 2, gid, Endian.big);
    });
    return COSStream()..data = buffer;
  }

  Uint8List _buildCidSetFromCids(Iterable<int> cids) {
    final cidList = cids is List<int> ? cids : List<int>.from(cids, growable: false);
    if (cidList.isEmpty) {
      return Uint8List(0);
    }
    final lastCid = cidList.last;
    final bytes = Uint8List(lastCid ~/ 8 + 1);
    for (final cid in cidList) {
      if (cid < 0) {
        continue;
      }
      final mask = 1 << (7 - cid % 8);
      bytes[cid ~/ 8] |= mask;
    }
    return bytes;
  }

  bool _buildVerticalHeader(COSDictionary cidFont) {
  final VerticalHeaderTable? verticalHeader = _ttf.getVerticalHeaderTable();
    if (verticalHeader == null) {
      return false;
    }

    final scale = _unitsPerEmScale == 0 ? 1.0 : _unitsPerEmScale;
    final v = (verticalHeader.ascender * scale).round();
    final w1 = (-verticalHeader.advanceHeightMax * scale).round();

    if (v != 880 || w1 != -1000) {
      final dw2 = COSArray()
        ..addObject(COSInteger(v))
        ..addObject(COSInteger(w1));
      cidFont[COSName.dw2] = dw2;
    }

    return true;
  }

  void _buildVerticalMetricsFromSubset(
    COSDictionary cidFont,
    SplayTreeMap<int, int> cidToGid,
  ) {
    if (!_buildVerticalHeader(cidFont)) {
      return;
    }

  final VerticalMetricsTable? vmtx = _ttf.getVerticalMetricsTable();
  final GlyphTable? glyf = _ttf.getGlyphTable();
  final HorizontalMetricsTable? hmtx = _ttf.getHorizontalMetricsTable();
  final VerticalHeaderTable? vhea = _ttf.getVerticalHeaderTable();
    if (vmtx == null || glyf == null || hmtx == null || vhea == null) {
      return;
    }

    final scale = _unitsPerEmScale == 0 ? 1.0 : _unitsPerEmScale;
    final defaultHeight = (vhea.ascender * scale).round();
    final defaultAdvance = (-vhea.advanceHeightMax * scale).round();

    final metrics = COSArray();
    COSArray? currentRange;
    var previousCid = -1;

    for (final cid in cidToGid.keys) {
      final GlyphData? glyph = glyf.getGlyph(cid);
      if (glyph == null) {
        continue;
      }

      final height = ((glyph.getYMaximum() + vmtx.getTopSideBearing(cid)) * scale).round();
      final advance = (-vmtx.getAdvanceHeight(cid) * scale).round();

      if (height == defaultHeight && advance == defaultAdvance) {
        previousCid = cid;
        continue;
      }

      if (currentRange == null || cid != previousCid + 1) {
        currentRange = COSArray();
        metrics.addObject(COSInteger(cid));
        metrics.addObject(currentRange);
      }

      final vx = (hmtx.getAdvanceWidth(cid) * scale / 2).round();
      currentRange
        ..addObject(COSInteger(advance))
        ..addObject(COSInteger(vx))
        ..addObject(COSInteger(height));

      previousCid = cid;
    }

    if (metrics.length > 0) {
      cidFont[COSName.w2] = metrics;
    }
  }

  void _writeToUnicode(
    COSDictionary type0Dictionary,
    Iterable<int> cids,
  ) {
    final cmap = _unicodeCmap;
    if (cmap == null) {
      return;
    }

    final writer = ToUnicodeWriter(wMode: _vertical ? 1 : 0);
    for (final cid in cids) {
      if (cid > 0xFFFF) {
        continue;
      }
      final codes = cmap.getCharCodes(cid);
      if (codes == null || codes.isEmpty) {
        continue;
      }
      final codePoint = codes.first;
      writer.add(cid, String.fromCharCodes(<int>[codePoint]));
    }

    final stream = PDStream.fromBytes(writer.toBytes());
    type0Dictionary[COSName.toUnicode] = stream.cosStream;
  }

  double _scaledAdvanceWidth(int gid) {
    final advance = _ttf.getAdvanceWidth(gid);
    if (_unitsPerEmScale == 0) {
      return advance.toDouble();
    }
    return advance * _unitsPerEmScale;
  }

  static double _computeUnitsPerEmScale(TrueTypeFont font) {
    final unitsPerEm = font.unitsPerEm;
    if (unitsPerEm <= 0) {
      return 1;
    }
    return 1000 / unitsPerEm;
  }

  static String _resolvePostScriptName(TrueTypeFont font) {
    final name = font.getName();
    if (name == null) {
      return 'CIDFontType2';
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'CIDFontType2';
    }
    return trimmed;
  }
}
