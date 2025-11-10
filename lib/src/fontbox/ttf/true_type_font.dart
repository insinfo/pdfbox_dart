import 'dart:typed_data';

import '../../io/exceptions.dart';

import '../../io/closeable.dart';
import '../io/ttf_data_stream.dart';
import '../util/bounding_box.dart';
import 'cmap_lookup.dart';
import 'cmap_table.dart';
import 'cmap_subtable.dart';
import 'digital_signature_table.dart';
import 'font_headers.dart';
import 'glyph_substitution_table.dart';
import 'glyph_table.dart';
import 'glyph_renderer.dart';
import 'glyph_positioning_table.dart';
import 'jstf/jstf_lookup_control.dart';
import 'table/fvar/font_variation_axis.dart';
import 'table/fvar/fvar_table.dart';
import 'variation/variation_coordinate_provider.dart';
import 'header_table.dart';
import 'horizontal_header_table.dart';
import 'horizontal_metrics_table.dart';
import 'index_to_location_table.dart';
import 'kerning_table.dart';
import 'maximum_profile_table.dart';
import 'naming_table.dart';
import 'os2_windows_metrics_table.dart';
import 'model/gsub_data.dart';
import 'post_script_table.dart';
import 'substituting_cmap_lookup.dart';
import 'ttf_table.dart';
import 'vertical_header_table.dart';
import 'vertical_metrics_table.dart';
import 'vertical_origin_table.dart';
import 'otl_table.dart';

/// TrueType/OpenType font container with lazy table parsing.
class TrueTypeFont
    implements
        Closeable,
        HasGlyphCount,
        HeaderTableProvider,
        HorizontalHeaderTableProvider,
        VerticalHeaderTableProvider,
        GlyphTableDependencies,
        VariationAxisConsumer,
        VariationCoordinateProvider {
  TrueTypeFont({TtfDataStream? data, int glyphCount = 0})
      : _data = data,
        numberOfGlyphs = glyphCount;

  factory TrueTypeFont.fromDataStream(TtfDataStream data) =>
      TrueTypeFont(data: data);

  final Map<String, TtfTable> _tables = <String, TtfTable>{};
  final TtfDataStream? _data;

  double _version = 0;

  @override
  int numberOfGlyphs;

  int _unitsPerEm = -1;
  bool _isClosed = false;

  bool enableGsub = true;
  bool get isEnableGsub => enableGsub;
  void setEnableGsub(bool value) => enableGsub = value;
  final List<String> enabledGsubFeatures = <String>[];
  Map<String, int>? _postScriptNames;
  bool _postScriptNamesLoaded = false;
  static final RegExp _gidNamePattern = RegExp(r'^g\d+$');

  List<FontVariationAxis> _variationAxes = const <FontVariationAxis>[];
  List<double> _variationCoordinates = const <double>[];

  double get version => _version;
  void setVersion(double value) => _version = value;

  int get unitsPerEm {
    if (_unitsPerEm == -1) {
      final header = getHeaderTable();
      _unitsPerEm = header?.unitsPerEm ?? 0;
    }
    return _unitsPerEm;
  }

  @override
  void close() {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    _data?.close();
  }

  void addTable(TtfTable table) {
    final tag = table.tag;
    if (tag == null) {
      throw ArgumentError('Table tag must be set before registration');
    }
    _tables[tag] = table;
  }

  Map<String, TtfTable> get tableMap => Map.unmodifiable(_tables);

  Iterable<TtfTable> get tables => _tables.values;

  int get originalDataSize => _data?.originalDataSize ?? 0;

  TtfTable? getTable(String tag) => _getTable(tag, initialize: true);

  Uint8List getTableBytes(TtfTable table) =>
      _readTableBytes(table, table.length);

  Uint8List getTableNBytes(TtfTable table, int limit) {
    final safeLength = limit < table.length ? limit : table.length;
    return _readTableBytes(table, safeLength);
  }

  void readTable(TtfTable table) => _readTable(table);

  void readTableHeaders(String tag, FontHeaders outHeaders) {
    final table = _tables[tag];
    if (table == null || table.offset <= 0 || table.length <= 0) {
      return;
    }
    final data = _data;
    if (data == null) {
      throw StateError('Backing TTF data stream is not available');
    }
    final saved = data.currentPosition;
    try {
      data.seek(table.offset);
      table.readHeaders(this, data, outHeaders);
    } finally {
      data.seek(saved);
    }
  }

  TtfTable? _getTable(String tag, {bool initialize = true}) {
    final table = _tables[tag];
    if (table == null) {
      return null;
    }
    if (!table.initialized && initialize) {
      _readTable(table);
    }
    return table;
  }

  void _readTable(TtfTable table) {
    final data = _data;
    if (data == null) {
      throw StateError('Backing TTF data stream is not available');
    }
    final saved = data.currentPosition;
    try {
      data.seek(table.offset);
      table.read(this, data);
      _updateDerivedState(table);
    } finally {
      data.seek(saved);
    }
  }

  Uint8List _readTableBytes(TtfTable table, int length) {
    final data = _data;
    if (data == null) {
      throw StateError('Backing TTF data stream is not available');
    }
    final saved = data.currentPosition;
    try {
      data.seek(table.offset);
      return data.readBytes(length);
    } finally {
      data.seek(saved);
    }
  }

  /// Returns a copy of the original font data stream.
  Uint8List copyFontData() {
    final data = _data;
    if (data == null) {
      throw StateError('Backing TTF data stream is not available');
    }
    final size = data.originalDataSize;
    if (size <= 0) {
      throw StateError('Original font data size is not available');
    }
    final saved = data.currentPosition;
    try {
      data.seek(0);
      return data.readBytes(size);
    } finally {
      data.seek(saved);
    }
  }

  void _updateDerivedState(TtfTable table) {
    if (table is MaximumProfileTable) {
      numberOfGlyphs = table.numGlyphs;
    } else if (table is HeaderTable) {
      _unitsPerEm = table.unitsPerEm;
    } else if (table is FvarTable) {
      updateVariationAxes(table.axes);
    }
  }

  int getAdvanceWidth(int gid) {
    final metrics = getHorizontalMetricsTable();
    return metrics?.getAdvanceWidth(gid) ?? 250;
  }

  int getAdvanceHeight(int gid) {
    final metrics = getVerticalMetricsTable();
    return metrics?.getAdvanceHeight(gid) ?? 250;
  }

  CmapTable? getCmapTable() => _getTable(CmapTable.tableTag) as CmapTable?;

  GlyphSubstitutionTable? getGsubTable() =>
      _getTable(GlyphSubstitutionTable.tableTag) as GlyphSubstitutionTable?;

  GlyphPositioningTable? getGposTable() =>
      _getTable(GlyphPositioningTable.tableTag) as GlyphPositioningTable?;

  OtlTable? getJstfTable() => _getTable(OtlTable.tableTag) as OtlTable?;

  GlyphPositioningExecutor? getGlyphPositioningExecutor() {
    final table = getGposTable();
    if (table == null) {
      return null;
    }
    return table.createExecutor();
  }

  JstfLookupControl resolveJstfLookupControl({
    required String scriptTag,
    String? languageTag,
    JstfAdjustmentMode mode = JstfAdjustmentMode.none,
  }) {
    if (mode == JstfAdjustmentMode.none) {
      return JstfLookupControl.empty;
    }
    final table = getJstfTable();
    if (table == null || !table.hasScripts) {
      return JstfLookupControl.empty;
    }
    final script = table.getScript(scriptTag);
    if (script == null) {
      return JstfLookupControl.empty;
    }
    final controller =
        JstfPriorityController(script, languageTag: languageTag);
    return controller.evaluate(mode);
  }

  @override
  HeaderTable? getHeaderTable() =>
      _getTable(HeaderTable.tableTag) as HeaderTable?;

  @override
  HorizontalHeaderTable? getHorizontalHeaderTable() =>
      _getTable(HorizontalHeaderTable.tableTag) as HorizontalHeaderTable?;

  @override
  IndexToLocationTable? getIndexToLocationTable() =>
      _getTable(IndexToLocationTable.tableTag) as IndexToLocationTable?;

  @override
  HorizontalMetricsTable? getHorizontalMetricsTable() =>
      _getTable(HorizontalMetricsTable.tableTag) as HorizontalMetricsTable?;

  @override
  MaximumProfileTable? getMaximumProfileTable() =>
      _getTable(MaximumProfileTable.tableTag) as MaximumProfileTable?;

  @override
  VerticalHeaderTable? getVerticalHeaderTable() =>
      _getTable(VerticalHeaderTable.tableTag) as VerticalHeaderTable?;

  VerticalMetricsTable? getVerticalMetricsTable() =>
      _getTable(VerticalMetricsTable.tableTag) as VerticalMetricsTable?;

  VerticalOriginTable? getVerticalOriginTable() =>
      _getTable(VerticalOriginTable.tableTag) as VerticalOriginTable?;

  KerningTable? getKerningTable() =>
      _getTable(KerningTable.tableTag) as KerningTable?;

  /// Returns the kerning adjustment (in font units) for [leftGid] followed by [rightGid].
  int getKerningAdjustment(int leftGid, int rightGid) {
    final gpos = getGposTable();
    final gposKerning = gpos?.getKerningValue(leftGid, rightGid) ?? 0;
    if (gposKerning != 0) {
      return gposKerning;
    }

    final kerning = getKerningTable();
    final subtable = kerning?.getHorizontalKerningSubtable();
    if (subtable == null) {
      return 0;
    }
    return subtable.getPairKerning(leftGid, rightGid);
  }

  Os2WindowsMetricsTable? getOs2WindowsMetricsTable() =>
      _getTable(Os2WindowsMetricsTable.tableTag) as Os2WindowsMetricsTable?;

  PostScriptTable? getPostScriptTable() =>
      _getTable(PostScriptTable.tableTag) as PostScriptTable?;

  NamingTable? getNamingTable() =>
      _getTable(NamingTable.tableTag) as NamingTable?;

  DigitalSignatureTable? getDigitalSignatureTable() =>
      _getTable(DigitalSignatureTable.tableTag) as DigitalSignatureTable?;

  GlyphTable? getGlyphTable() => _getTable(GlyphTable.tableTag) as GlyphTable?;

  /// Returns the PostScript name stored in the naming table, if present.
  String? getName() => getNamingTable()?.getPostScriptName();

  /// Returns the preferred Unicode cmap lookup, optionally allowing fallback.
  CMapLookup? getUnicodeCmapLookup({bool isStrict = true}) {
    final cmapTable = getCmapTable();
    if (cmapTable == null) {
      if (isStrict) {
        throw IOException(
            'The TrueType font does not contain a \'cmap\' table');
      }
      return null;
    }

    CmapSubtable? cmap = cmapTable.getSubtable(
        CmapTable.platformUnicode, CmapTable.encodingUnicode20Full);
    cmap ??= cmapTable.getSubtable(
        CmapTable.platformWindows, CmapTable.encodingWinUnicodeFull);
    cmap ??= cmapTable.getSubtable(
        CmapTable.platformUnicode, CmapTable.encodingUnicode20Bmp);
    cmap ??= cmapTable.getSubtable(
        CmapTable.platformWindows, CmapTable.encodingWinUnicodeBmp);
    cmap ??= cmapTable.getSubtable(
        CmapTable.platformWindows, CmapTable.encodingWinSymbol);
    cmap ??= cmapTable.getSubtable(
        CmapTable.platformUnicode, CmapTable.encodingUnicode11);

    if (cmap == null) {
      if (isStrict) {
        throw IOException('The TrueType font does not contain a Unicode cmap');
      }
      if (cmapTable.cmaps.isNotEmpty) {
        cmap = cmapTable.cmaps.first;
      } else {
        return null;
      }
    }

    for (final variation in cmapTable.cmaps) {
      if (!identical(variation, cmap) && variation.format == 14) {
        cmap.mergeVariationData(variation);
      }
    }

    final List<String> features;
    if (!enableGsub || enabledGsubFeatures.isEmpty) {
      features = const <String>[];
    } else {
      features = List<String>.from(enabledGsubFeatures);
    }

    if (features.isEmpty) {
      return cmap;
    }

    final gsub = getGsubTable();
    if (gsub == null) {
      return cmap;
    }

    return SubstitutingCmapLookup(cmap, gsub, features);
  }

  /// Returns the glyph index associated with a PostScript [name].
  int nameToGid(String name) {
    _ensurePostScriptNamesLoaded();
    final postNames = _postScriptNames;
    if (postNames != null) {
      final gid = postNames[name];
      if (gid != null && gid > 0) {
        final glyphLimit = numberOfGlyphs;
        if (glyphLimit <= 0 || gid < glyphLimit) {
          return gid;
        }
      }
    }

    final unicode = _parseUniName(name);
    if (unicode >= 0) {
      final cmap = getUnicodeCmapLookup(isStrict: false);
      if (cmap != null) {
        final gid = cmap.getGlyphId(unicode);
        if (gid > 0) {
          return gid;
        }
      }
    }

    if (_gidNamePattern.hasMatch(name)) {
      final numeric = int.tryParse(name.substring(1));
      return numeric ?? 0;
    }

    return 0;
  }

  /// Indicates whether a glyph with the given PostScript [name] exists.
  bool hasGlyph(String name) => nameToGid(name) != 0;

  /// Returns a drawable path for the glyph referenced by [name].
  GlyphPath getPath(String name) {
    final gid = nameToGid(name);
    if (gid <= 0) {
      return GlyphPath();
    }

    final table = getGlyphTable();
    if (table == null) {
      throw StateError('Glyph table has not been loaded');
    }

    final glyph = table.getGlyph(gid);
    if (glyph == null) {
      return GlyphPath();
    }

    return glyph.getPath();
  }

  /// Returns the glyph advance width in font design units.
  double getWidth(String name) {
    final gid = nameToGid(name);
    if (gid <= 0) {
      return 0;
    }

    final advanceWidth = getAdvanceWidth(gid);
    return advanceWidth.toDouble();
  }

  /// Returns the font's bounding box scaled to a 1000 unit em square.
  BoundingBox? getFontBBox() {
    final header = getHeaderTable();
    if (header == null) {
      return null;
    }

    final units = unitsPerEm;
    if (units <= 0) {
      return null;
    }

    final scale = 1000.0 / units;
    return BoundingBox.fromValues(
      header.xMin * scale,
      header.yMin * scale,
      header.xMax * scale,
      header.yMax * scale,
    );
  }

  /// Returns the font matrix scaled relative to the units-per-em value.
  List<double> getFontMatrix() {
    final units = unitsPerEm;
    if (units <= 0) {
      return const <double>[0.001, 0, 0, 0.001, 0, 0];
    }

    final scale = 1.0 / units;
    return <double>[scale, 0, 0, scale, 0, 0];
  }

  /// Enables a specific glyph substitution [feature].
  void enableGsubFeature(String feature) {
    if (!enabledGsubFeatures.contains(feature)) {
      enabledGsubFeatures.add(feature);
    }
  }

  /// Disables a previously enabled glyph substitution [feature].
  void disableGsubFeature(String feature) {
    enabledGsubFeatures.remove(feature);
  }

  /// Enables the standard vertical glyph substitution feature tags.
  void enableVerticalSubstitutions() {
    enableGsubFeature('vrt2');
    enableGsubFeature('vert');
  }

  /// Returns the glyph substitution data for this font, if available.
  GsubData getGsubData() {
    if (!enableGsub) {
      return GsubData.noDataFound;
    }
    final table = getGsubTable();
    return table?.getGsubData() ?? GsubData.noDataFound;
  }

  /// Mapeia uma sequência de codepoints para glyph IDs, consumindo seletores de
  /// variação e aplicando GSUB quando habilitado.
  List<int> mapCodePointsToGlyphIds(Iterable<int> codePoints) {
    final lookup = getUnicodeCmapLookup(isStrict: false);
    if (lookup == null) {
      return const <int>[];
    }
    if (lookup is SubstitutingCmapLookup) {
      return lookup.mapCodePoints(codePoints);
    }
    if (lookup is CmapSubtable) {
      return lookup.mapCodePoints(codePoints);
    }

    final source = codePoints is List<int>
        ? codePoints
        : List<int>.from(codePoints, growable: false);
    final glyphIds = <int>[];

    for (var index = 0; index < source.length; index++) {
      final codePoint = source[index];
      if (CmapSubtable.isVariationSelector(codePoint)) {
        continue;
      }

      int? variationSelector;
      if (index + 1 < source.length &&
          CmapSubtable.isVariationSelector(source[index + 1])) {
        variationSelector = source[index + 1];
        index++;
      }

      glyphIds.add(lookup.getGlyphId(codePoint, variationSelector));
    }

    return glyphIds;
  }

  List<FontVariationAxis> get variationAxes =>
      List<FontVariationAxis>.unmodifiable(_variationAxes);

  List<double> get variationCoordinates =>
      List<double>.unmodifiable(_variationCoordinates);

  @override
  List<double> get normalizedVariationCoordinates {
    if (_variationAxes.isEmpty) {
      return const <double>[];
    }
    final normalized =
        List<double>.filled(_variationAxes.length, 0.0, growable: false);
    for (var i = 0; i < _variationAxes.length; i++) {
      final coordinate =
          i < _variationCoordinates.length ? _variationCoordinates[i] : 0.0;
      normalized[i] = _clampNormalized(coordinate);
    }
    return List<double>.unmodifiable(normalized);
  }

  void setVariationCoordinates(List<double> coordinates) {
    if (_variationAxes.isEmpty) {
      _variationCoordinates = const <double>[];
      return;
    }
    final next = List<double>.filled(_variationAxes.length, 0.0,
        growable: false);
    final limit =
        coordinates.length < next.length ? coordinates.length : next.length;
    for (var i = 0; i < limit; i++) {
      next[i] = _clampNormalized(coordinates[i]);
    }
    _variationCoordinates = next;
  }

  void setVariationCoordinate(String axisTag, double value) {
    final index = _variationAxes.indexWhere((axis) => axis.tag == axisTag);
    if (index < 0) {
      return;
    }
    _ensureVariationCoordinateCapacity();
    _variationCoordinates[index] = _clampNormalized(value);
  }

  void setVariationCoordinateAt(int axisIndex, double value) {
    if (axisIndex < 0) {
      return;
    }
    _ensureVariationCoordinateCapacity();
    if (axisIndex >= _variationCoordinates.length) {
      return;
    }
    _variationCoordinates[axisIndex] = _clampNormalized(value);
  }

  @override
  void updateVariationAxes(List<FontVariationAxis> axes) {
    final previousValues = <String, double>{};
    for (var i = 0;
        i < _variationAxes.length && i < _variationCoordinates.length;
        i++) {
      previousValues[_variationAxes[i].tag] = _variationCoordinates[i];
    }
    _variationAxes = List<FontVariationAxis>.unmodifiable(axes);
    _variationCoordinates = List<double>.generate(
      _variationAxes.length,
      (index) {
        final axis = _variationAxes[index];
        final existing = previousValues[axis.tag];
        return existing == null ? 0.0 : _clampNormalized(existing);
      },
      growable: false,
    );
  }

  void _ensureVariationCoordinateCapacity() {
    if (_variationCoordinates.length == _variationAxes.length) {
      return;
    }
    final next = List<double>.generate(
      _variationAxes.length,
      (index) => index < _variationCoordinates.length
          ? _variationCoordinates[index]
          : 0.0,
      growable: false,
    );
    _variationCoordinates = next;
  }

  void _ensurePostScriptNamesLoaded() {
    if (_postScriptNamesLoaded) {
      return;
    }
    _postScriptNamesLoaded = true;
    final post = getPostScriptTable();
    final names = post?.glyphNames;
    if (names == null) {
      _postScriptNames = null;
      return;
    }
    final map = <String, int>{};
    for (var i = 0; i < names.length; i++) {
      final glyphName = names[i];
      if (glyphName.isEmpty) {
        continue;
      }
      map[glyphName] = i;
    }
    _postScriptNames = map.isEmpty ? null : map;
  }

  int _parseUniName(String name) {
    if (name.startsWith('uni') && name.length == 7) {
      try {
        return int.parse(name.substring(3), radix: 16);
      } catch (_) {
        return -1;
      }
    }
    return -1;
  }

  double _clampNormalized(double value) {
    if (value <= -1.0) {
      return -1.0;
    }
    if (value >= 1.0) {
      return 1.0;
    }
    if (value.abs() < 1e-9) {
      return 0.0;
    }
    return value;
  }

  @override
  String toString() {
    try {
      final name = getName();
      return name ?? '(null)';
    } on IOException catch (e) {
      return '(null - ${e.message})';
    } catch (e) {
      return '(null - $e)';
    }
  }
}
