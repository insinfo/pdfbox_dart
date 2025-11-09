import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:pdfbox_dart/src/io/exceptions.dart';

import 'cmap_lookup.dart';
import 'cmap_table.dart';
import 'glyph_table.dart';
import 'header_table.dart';
import 'horizontal_header_table.dart';
import 'horizontal_metrics_table.dart';
import 'index_to_location_table.dart';
import 'maximum_profile_table.dart';
import 'name_record.dart';
import 'naming_table.dart';
import 'os2_windows_metrics_table.dart';
import 'post_script_table.dart';
import 'true_type_font.dart';
import 'wgl4_names.dart';

/// Subsetter for TrueType (TTF) fonts, ported from Apache FontBox.
class TtfSubsetter {
  TtfSubsetter(this._ttf, [List<String>? tablesToKeep])
      : _keepTables = tablesToKeep {
    final cmap = _ttf.getUnicodeCmapLookup();
    if (cmap == null) {
      throw IOException('The TrueType font does not contain a Unicode cmap');
    }
    _unicodeCmap = cmap;
    _glyphIds.add(0);
  }

  static final Logger _log = Logger('fontbox.TtfSubsetter');
  static final Uint8List _padBuf = Uint8List.fromList(<int>[0, 0, 0, 0]);
  static const int _secondsBetween1904And1970 = 2082844800;

  final TrueTypeFont _ttf;
  final List<String>? _keepTables;
  late final CMapLookup _unicodeCmap;

  final SplayTreeMap<int, int> _uniToGid = SplayTreeMap<int, int>();
  final SplayTreeSet<int> _glyphIds = SplayTreeSet<int>();
  final Set<int> _invisibleGlyphIds = <int>{};

  String? _prefix;
  bool _hasAddedCompoundReferences = false;
  List<int>? _glyphIdListCache;
  Map<int, int>? _oldToNewGidCache;

  /// Sets the prefix to add to the font's PostScript name.
  void setPrefix(String? prefix) => _prefix = prefix;

  /// Adds a single Unicode [codePoint] to the subset.
  void add(int codePoint) {
    final gid = _unicodeCmap.getGlyphId(codePoint);
    if (gid != 0) {
      _uniToGid[codePoint] = gid;
      _glyphIds.add(gid);
      _invalidateGlyphCaches();
    }
  }

  /// Adds all Unicode [codePoints] to the subset.
  void addAll(Iterable<int> codePoints) {
    for (final codePoint in codePoints) {
      add(codePoint);
    }
  }

  /// Forces the glyph for [codePoint] to become invisible in the subset.
  void forceInvisible(int codePoint) {
    final gid = _unicodeCmap.getGlyphId(codePoint);
    if (gid != 0) {
      _invisibleGlyphIds.add(gid);
    }
  }

  /// Adds additional glyph IDs that must be retained as part of the subset.
  void addGlyphIds(Iterable<int> glyphIds) {
    if (glyphIds.isEmpty) {
      return;
    }
    _glyphIds.addAll(glyphIds);
    _invalidateGlyphCaches();
  }

  /// Returns the map of new GIDs to the original font GIDs.
  Map<int, int> getGidMap() {
    _ensureCompoundReferencesAdded();
    _ensureGlyphOrderCache();
    final map = <int, int>{};
    final glyphList = _glyphIdListCache!;
    for (var newGid = 0; newGid < glyphList.length; newGid++) {
      map[newGid] = glyphList[newGid];
    }
    return map;
  }

  /// Builds the subset font and returns the resulting byte array.
  Uint8List buildSubset() {
    if (_glyphIds.isEmpty && _uniToGid.isEmpty) {
      _log.info('font subset is empty');
    }

    _ensureCompoundReferencesAdded();
    _ensureGlyphOrderCache();

    final glyphList = List<int>.from(_glyphIdListCache!);
    final newLoca = List<int>.filled(glyphList.length + 1, 0);

    final head = _buildHeadTable();
    final hhea = _buildHheaTable(glyphList);
    final maxp = _buildMaxpTable(glyphList.length);
    final name = _buildNameTable();
    final os2 = _buildOs2Table();
    final glyf = _buildGlyfTable(glyphList, newLoca);
    final loca = _buildLocaTable(newLoca);
    final cmap = _buildCmapTable();
    final hmtx = _buildHmtxTable(glyphList);
    final post = _buildPostTable(glyphList);

    final tables = SplayTreeMap<String, Uint8List>();
    if (os2 != null) {
      tables[Os2WindowsMetricsTable.tableTag] = os2;
    }
    if (cmap != null) {
      tables[CmapTable.tableTag] = cmap;
    }
    tables[GlyphTable.tableTag] = glyf;
    tables[HeaderTable.tableTag] = head;
    tables[HorizontalHeaderTable.tableTag] = hhea;
    tables[HorizontalMetricsTable.tableTag] = hmtx;
    tables[IndexToLocationTable.tableTag] = loca;
    tables[MaximumProfileTable.tableTag] = maxp;
    if (name != null) {
      tables[NamingTable.tableTag] = name;
    }
    if (post != null) {
      tables[PostScriptTable.tableTag] = post;
    }

    final keepTables = _keepTables;
    for (final entry in _ttf.tableMap.entries) {
      final tag = entry.key;
      final table = entry.value;
      if (!tables.containsKey(tag) &&
          (keepTables == null || keepTables.contains(tag))) {
        tables[tag] = _ttf.getTableBytes(table);
      }
    }

    final tableRecords = <_TableRecord>[];
    var offset = 12 + 16 * tables.length;
    for (final entry in tables.entries) {
      final data = Uint8List.fromList(entry.value);
      final record = _TableRecord(
        tag: entry.key,
        data: data,
        checksum: _computeChecksum(data),
        offset: offset,
        length: data.length,
      );
      tableRecords.add(record);
      offset += _paddedLength(data.length);
    }

    final outputLength = offset;
    final result = Uint8List(outputLength);
    final byteView = ByteData.sublistView(result);

    _writeSfntHeader(byteView, tables.length);

    var dirOffset = 12;
    for (final record in tableRecords) {
      _writeTag(result, dirOffset, record.tag);
      dirOffset += 4;
      byteView.setUint32(dirOffset, record.checksum, Endian.big);
      dirOffset += 4;
      byteView.setUint32(dirOffset, record.offset, Endian.big);
      dirOffset += 4;
      byteView.setUint32(dirOffset, record.length, Endian.big);
      dirOffset += 4;
    }

    for (final record in tableRecords) {
      final start = record.offset;
      result.setRange(start, start + record.data.length, record.data);
      final padding = _paddedLength(record.data.length) - record.data.length;
      if (padding > 0) {
        result.setRange(start + record.data.length,
            start + record.data.length + padding, _padBuf.sublist(0, padding));
      }
    }

    final headRecord =
        tableRecords.firstWhere((record) => record.tag == HeaderTable.tableTag);
    final adjustment =
        (0xB1B0AFBA - (_computeChecksum(result) & 0xffffffff)) & 0xffffffff;
    byteView.setUint32(headRecord.offset + 8, adjustment, Endian.big);
    ByteData.sublistView(headRecord.data).setUint32(8, adjustment, Endian.big);

    return result;
  }

  void _ensureCompoundReferencesAdded() {
    if (_hasAddedCompoundReferences) {
      return;
    }
    _hasAddedCompoundReferences = true;

    final glyphTable = _ttf.getGlyphTable();
    final locaTable = _ttf.getIndexToLocationTable();
    if (glyphTable == null || locaTable == null) {
      throw IOException(
          'Font is missing glyf/loca tables needed for subsetting');
    }

    final glyfData = _ttf.getTableBytes(glyphTable);
    final offsets = locaTable.offsets;
    bool hasNested;
    do {
      final glyphsToAdd = <int>{};
      for (final gid in _glyphIds) {
        if (gid < 0 || gid + 1 >= offsets.length) {
          continue;
        }
        final start = offsets[gid];
        final end = offsets[gid + 1];
        final length = end - start;
        if (length <= 0 || start < 0 || end > glyfData.length) {
          continue;
        }
        final glyphBytes = glyfData.sublist(start, end);
        if (!_isCompositeGlyph(glyphBytes)) {
          continue;
        }
        _collectCompositeReferences(glyphBytes, glyphsToAdd);
      }
      hasNested = glyphsToAdd.isNotEmpty;
      if (hasNested) {
        _glyphIds.addAll(glyphsToAdd);
        _invalidateGlyphCaches();
      }
    } while (hasNested);
  }

  Uint8List _buildHeadTable() {
    final header = _ttf.getHeaderTable();
    if (header == null) {
      throw IOException('Font is missing head table');
    }

    final builder = BytesBuilder(copy: false);
    _writeFixed(builder, header.version);
    _writeFixed(builder, header.fontRevision);
    _writeUint32(builder, 0);
    _writeUint32(builder, header.magicNumber);
    _writeUint16(builder, header.flags);
    _writeUint16(builder, header.unitsPerEm);
    _writeLongDateTime(builder, header.created);
    _writeLongDateTime(builder, header.modified);
    _writeInt16(builder, header.xMin);
    _writeInt16(builder, header.yMin);
    _writeInt16(builder, header.xMax);
    _writeInt16(builder, header.yMax);
    _writeUint16(builder, header.macStyle);
    _writeUint16(builder, header.lowestRecPpem);
    _writeInt16(builder, header.fontDirectionHint);
    _writeInt16(builder, 1); // force long format of 'loca'
    _writeInt16(builder, header.glyphDataFormat);
    return builder.takeBytes();
  }

  Uint8List _buildHheaTable(List<int> glyphList) {
    final header = _ttf.getHorizontalHeaderTable();
    if (header == null) {
      throw IOException('Font is missing hhea table');
    }

    final builder = BytesBuilder(copy: false);
    _writeFixed(builder, header.version);
    _writeInt16(builder, header.ascender);
    _writeInt16(builder, header.descender);
    _writeInt16(builder, header.lineGap);
    _writeUint16(builder, header.advanceWidthMax);
    _writeInt16(builder, header.minLeftSideBearing);
    _writeInt16(builder, header.minRightSideBearing);
    _writeInt16(builder, header.xMaxExtent);
    _writeInt16(builder, header.caretSlopeRise);
    _writeInt16(builder, header.caretSlopeRun);
    _writeInt16(builder, header.reserved1);
    _writeInt16(builder, header.reserved2);
    _writeInt16(builder, header.reserved3);
    _writeInt16(builder, header.reserved4);
    _writeInt16(builder, header.reserved5);
    _writeInt16(builder, header.metricDataFormat);

    final numHMetrics = header.numberOfHMetrics;
    var hMetricsCount = glyphList.where((gid) => gid < numHMetrics).length;
    if (glyphList.isNotEmpty && glyphList.last >= numHMetrics) {
      final lastMetricIndex = numHMetrics - 1;
      if (lastMetricIndex >= 0 && !_glyphIds.contains(lastMetricIndex)) {
        hMetricsCount++;
      }
    }
    _writeUint16(builder, hMetricsCount);

    return builder.takeBytes();
  }

  Uint8List _buildMaxpTable(int glyphCount) {
    final maxp = _ttf.getMaximumProfileTable();
    if (maxp == null) {
      throw IOException('Font is missing maxp table');
    }

    final builder = BytesBuilder(copy: false);
    _writeFixed(builder, maxp.version);
    _writeUint16(builder, glyphCount);
    if (maxp.version >= 1.0) {
      _writeUint16(builder, maxp.maxPoints);
      _writeUint16(builder, maxp.maxContours);
      _writeUint16(builder, maxp.maxCompositePoints);
      _writeUint16(builder, maxp.maxCompositeContours);
      _writeUint16(builder, maxp.maxZones);
      _writeUint16(builder, maxp.maxTwilightPoints);
      _writeUint16(builder, maxp.maxStorage);
      _writeUint16(builder, maxp.maxFunctionDefs);
      _writeUint16(builder, maxp.maxInstructionDefs);
      _writeUint16(builder, maxp.maxStackElements);
      _writeUint16(builder, maxp.maxSizeOfInstructions);
      _writeUint16(builder, maxp.maxComponentElements);
      _writeUint16(builder, maxp.maxComponentDepth);
    }
    return builder.takeBytes();
  }

  Uint8List? _buildOs2Table() {
    final os2 = _ttf.getOs2WindowsMetricsTable();
    final keepTables = _keepTables;
    if (os2 == null ||
        _uniToGid.isEmpty ||
        (keepTables != null &&
            !keepTables.contains(Os2WindowsMetricsTable.tableTag))) {
      return null;
    }

    final builder = BytesBuilder(copy: false);
    _writeUint16(builder, os2.version);
    _writeInt16(builder, os2.averageCharWidth);
    _writeUint16(builder, os2.weightClass);
    _writeUint16(builder, os2.widthClass);
    _writeInt16(builder, os2.fsType);
    _writeInt16(builder, os2.subscriptXSize);
    _writeInt16(builder, os2.subscriptYSize);
    _writeInt16(builder, os2.subscriptXOffset);
    _writeInt16(builder, os2.subscriptYOffset);
    _writeInt16(builder, os2.superscriptXSize);
    _writeInt16(builder, os2.superscriptYSize);
    _writeInt16(builder, os2.superscriptXOffset);
    _writeInt16(builder, os2.superscriptYOffset);
    _writeInt16(builder, os2.strikeoutSize);
    _writeInt16(builder, os2.strikeoutPosition);
    _writeInt16(builder, os2.familyClass);
    builder.add(os2.panose);
    _writeUint32(builder, 0);
    _writeUint32(builder, 0);
    _writeUint32(builder, 0);
    _writeUint32(builder, 0);
    builder.add(latin1.encode(os2.achVendId));
    _writeUint16(builder, os2.fsSelection);
    final unicodeKeys = _uniToGid.keys.toList();
    _writeUint16(builder, unicodeKeys.first);
    _writeUint16(builder, unicodeKeys.last);
    _writeUint16(builder, os2.typoAscender);
    _writeUint16(builder, os2.typoDescender);
    _writeUint16(builder, os2.typoLineGap);
    _writeUint16(builder, os2.winAscent);
    _writeUint16(builder, os2.winDescent);
    return builder.takeBytes();
  }

  Uint8List _buildLocaTable(List<int> newOffsets) {
    final builder = BytesBuilder(copy: false);
    for (final offset in newOffsets) {
      _writeUint32(builder, offset);
    }
    return builder.takeBytes();
  }

  Uint8List _buildGlyfTable(List<int> glyphList, List<int> newOffsets) {
    final glyphTable = _ttf.getGlyphTable();
    final locaTable = _ttf.getIndexToLocationTable();
    if (glyphTable == null || locaTable == null) {
      throw IOException('Font is missing glyf/loca tables');
    }

    final glyfData = _ttf.getTableBytes(glyphTable);
    final offsets = locaTable.offsets;
    final builder = BytesBuilder(copy: false);

    var newOffset = 0;
    for (var i = 0; i < glyphList.length; i++) {
      final gid = glyphList[i];
      final start = offsets[gid];
      final end = offsets[gid + 1];
      final length = end - start;
      newOffsets[i] = newOffset;

      if (length <= 0 || start < 0 || end > glyfData.length) {
        continue;
      }

      if (_invisibleGlyphIds.contains(gid)) {
        continue;
      }

      final glyphBytes = Uint8List.fromList(glyfData.sublist(start, end));
      if (_isCompositeGlyph(glyphBytes)) {
        final consumed = _rewriteCompositeGlyph(glyphBytes);
        builder.add(glyphBytes.sublist(0, consumed));
        newOffset += consumed;
      } else {
        builder.add(glyphBytes);
        newOffset += glyphBytes.length;
      }

      final pad = newOffset % 4;
      if (pad != 0) {
        final padding = 4 - pad;
        builder.add(_padBuf.sublist(0, padding));
        newOffset += padding;
      }
    }
    newOffsets[glyphList.length] = newOffset;

    return builder.takeBytes();
  }

  Uint8List? _buildCmapTable() {
    final cmapTable = _ttf.getCmapTable();
    final keepTables = _keepTables;
    if (cmapTable == null ||
        _uniToGid.isEmpty ||
        (keepTables != null && !keepTables.contains(CmapTable.tableTag))) {
      return null;
    }

    final entries = _uniToGid.entries.toList();
    if (entries.isEmpty) {
      return null;
    }

    final builder = BytesBuilder(copy: false);
    _writeUint16(builder, 0);
    _writeUint16(builder, 1);
    _writeUint16(builder, CmapTable.platformWindows);
    _writeUint16(builder, CmapTable.encodingWinUnicodeBmp);
    _writeUint32(builder, 12);

    var lastEntry = entries.first;
    var prevEntry = lastEntry;
    var lastNewGid = _getNewGlyphId(lastEntry.value);

    final startCode = List<int>.filled(entries.length + 1, 0);
    final endCode = List<int>.filled(entries.length + 1, 0);
    final idDelta = List<int>.filled(entries.length + 1, 0);
    var segCount = 0;

    for (var i = 1; i < entries.length; i++) {
      final entry = entries[i];
      final curNewGid = _getNewGlyphId(entry.value);
      final codePoint = entry.key;
      if (codePoint > 0xFFFF) {
        throw UnsupportedError('non-BMP Unicode character');
      }
      if (codePoint != prevEntry.key + 1 ||
          curNewGid - lastNewGid != codePoint - lastEntry.key) {
        if (lastNewGid != 0) {
          startCode[segCount] = lastEntry.key;
          endCode[segCount] = prevEntry.key;
          idDelta[segCount] = lastNewGid - lastEntry.key;
          segCount++;
        } else if (lastEntry.key != prevEntry.key) {
          startCode[segCount] = lastEntry.key + 1;
          endCode[segCount] = prevEntry.key;
          idDelta[segCount] = lastNewGid - lastEntry.key;
          segCount++;
        }
        lastNewGid = curNewGid;
        lastEntry = entry;
      }
      prevEntry = entry;
    }

    startCode[segCount] = lastEntry.key;
    endCode[segCount] = prevEntry.key;
    idDelta[segCount] = lastNewGid - lastEntry.key;
    segCount++;

    startCode[segCount] = 0xFFFF;
    endCode[segCount] = 0xFFFF;
    idDelta[segCount] = 1;
    segCount++;

    final searchRange = 2 * _highestPowerOf2(segCount);
    _writeUint16(builder, 4);
    _writeUint16(builder, 16 + segCount * 8);
    _writeUint16(builder, 0);
    _writeUint16(builder, segCount * 2);
    _writeUint16(builder, searchRange);
    _writeUint16(builder, _log2(searchRange ~/ 2));
    _writeUint16(builder, segCount * 2 - searchRange);

    for (var i = 0; i < segCount; i++) {
      _writeUint16(builder, endCode[i]);
    }
    _writeUint16(builder, 0);
    for (var i = 0; i < segCount; i++) {
      _writeUint16(builder, startCode[i]);
    }
    for (var i = 0; i < segCount; i++) {
      _writeUint16(builder, idDelta[i]);
    }
    for (var i = 0; i < segCount; i++) {
      _writeUint16(builder, 0);
    }

    return builder.takeBytes();
  }

  Uint8List? _buildPostTable(List<int> glyphList) {
    final post = _ttf.getPostScriptTable();
    final keepTables = _keepTables;
    if (post == null ||
        post.glyphNames == null ||
        (keepTables != null &&
            !keepTables.contains(PostScriptTable.tableTag))) {
      return null;
    }

    final builder = BytesBuilder(copy: false);
    _writeFixed(builder, 2.0);
    _writeFixed(builder, post.italicAngle);
    _writeInt16(builder, post.underlinePosition);
    _writeInt16(builder, post.underlineThickness);
    _writeUint32(builder, post.isFixedPitch);
    _writeUint32(builder, post.minMemType42);
    _writeUint32(builder, post.maxMemType42);
    _writeUint32(builder, post.minMemType1);
    _writeUint32(builder, post.maxMemType1);

    _writeUint16(builder, glyphList.length);

    final names = LinkedHashMap<String, int>();
    for (final gid in glyphList) {
      final name = post.getName(gid) ?? '.notdef';
      final macId = Wgl4Names.getGlyphIndex(name);
      if (macId != null) {
        _writeUint16(builder, macId);
      } else {
        final ordinal = names.putIfAbsent(name, () => names.length);
        _writeUint16(builder, 258 + ordinal);
      }
    }

    for (final name in names.keys) {
      final bytes = latin1.encode(name);
      _writeUint8(builder, bytes.length);
      builder.add(bytes);
    }

    return builder.takeBytes();
  }

  Uint8List _buildHmtxTable(List<int> glyphList) {
    final hhea = _ttf.getHorizontalHeaderTable();
    final hmtx = _ttf.getHorizontalMetricsTable();
    if (hhea == null || hmtx == null) {
      throw IOException('Font is missing hhea/hmtx tables');
    }

    final hmtxBytes = _ttf.getTableBytes(hmtx);
    final builder = BytesBuilder(copy: false);

    final lastMetricIndex = hhea.numberOfHMetrics - 1;
    var needLastGidWidth = glyphList.isNotEmpty &&
        glyphList.last > lastMetricIndex &&
        !_glyphIds.contains(lastMetricIndex);

    for (final gid in glyphList) {
      if (gid <= lastMetricIndex) {
        if (_invisibleGlyphIds.contains(gid)) {
          builder.add(_padBuf.sublist(0, 4));
        } else {
          final slice = _tableView(hmtxBytes, gid * 4, 4);
          builder.add(slice);
        }
      } else {
        if (needLastGidWidth) {
          needLastGidWidth = false;
          final slice = _tableView(hmtxBytes, lastMetricIndex * 4, 2);
          builder.add(slice);
        }
        final offset =
            hhea.numberOfHMetrics * 4 + (gid - hhea.numberOfHMetrics) * 2;
        final slice = _tableView(hmtxBytes, offset, 2);
        builder.add(slice);
      }
    }

    return builder.takeBytes();
  }

  Uint8List? _buildNameTable() {
    final naming = _ttf.getNamingTable();
    final keepTables = _keepTables;
    if (naming == null ||
        (keepTables != null && !keepTables.contains(NamingTable.tableTag))) {
      return null;
    }

    final records =
        naming.getNameRecords().where(_shouldCopyNameRecord).toList();
    if (records.isEmpty) {
      return null;
    }

    final encodedNames = <List<int>>[];
    for (final record in records) {
      var value = record.string ?? '';
      if (record.nameId == NameRecord.namePostScriptName && _prefix != null) {
        value = '$_prefix$value';
      }
      encodedNames.add(_encodeNameString(
          value, record.platformId, record.platformEncodingId));
    }

    final builder = BytesBuilder(copy: false);
    _writeUint16(builder, 0);
    _writeUint16(builder, records.length);
    _writeUint16(builder, 6 + records.length * 12);

    var offset = 0;
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final nameBytes = encodedNames[i];
      _writeUint16(builder, record.platformId);
      _writeUint16(builder, record.platformEncodingId);
      _writeUint16(builder, record.languageId);
      _writeUint16(builder, record.nameId);
      _writeUint16(builder, nameBytes.length);
      _writeUint16(builder, offset);
      offset += nameBytes.length;
    }

    for (final bytes in encodedNames) {
      builder.add(bytes);
    }

    return builder.takeBytes();
  }

  bool _isCompositeGlyph(Uint8List glyphBytes) {
    if (glyphBytes.length < 2) {
      return false;
    }
    final view = ByteData.sublistView(glyphBytes);
    return view.getInt16(0, Endian.big) == -1;
  }

  void _collectCompositeReferences(Uint8List glyphBytes, Set<int> out) {
    final view = ByteData.sublistView(glyphBytes);
    var offset = 10;
    var flags = 0;
    do {
      if (offset + 4 > glyphBytes.length) {
        return;
      }
      flags = view.getUint16(offset, Endian.big);
      offset += 2;
      final componentGid = view.getUint16(offset, Endian.big);
      offset += 2;
      if (!_glyphIds.contains(componentGid)) {
        out.add(componentGid);
      }
      offset += (flags & 1) != 0 ? 4 : 2;
      if ((flags & 0x0080) != 0) {
        offset += 8;
      } else if ((flags & 0x0040) != 0) {
        offset += 4;
      } else if ((flags & 0x0008) != 0) {
        offset += 2;
      }
    } while ((flags & 0x0020) != 0 && offset < glyphBytes.length);
  }

  int _rewriteCompositeGlyph(Uint8List glyphBytes) {
    final view = ByteData.sublistView(glyphBytes);
    var offset = 10;
    var flags = 0;
    do {
      if (offset + 4 > glyphBytes.length) {
        return offset;
      }
      flags = view.getUint16(offset, Endian.big);
      offset += 2;
      final componentGid = view.getUint16(offset, Endian.big);
      final newComponentGid = _getNewGlyphId(componentGid);
      view.setUint16(offset, newComponentGid, Endian.big);
      offset += 2;
      offset += (flags & 1) != 0 ? 4 : 2;
      if ((flags & 0x0080) != 0) {
        offset += 8;
      } else if ((flags & 0x0040) != 0) {
        offset += 4;
      } else if ((flags & 0x0008) != 0) {
        offset += 2;
      }
    } while ((flags & 0x0020) != 0 && offset < glyphBytes.length);

    if ((flags & 0x0100) != 0) {
      if (offset + 2 > glyphBytes.length) {
        return glyphBytes.length;
      }
      final numInstr = view.getUint16(offset, Endian.big);
      offset += 2 + numInstr;
      if (offset > glyphBytes.length) {
        offset = glyphBytes.length;
      }
    }

    return offset;
  }

  bool _shouldCopyNameRecord(NameRecord record) {
    return record.platformId == NameRecord.platformWindows &&
        record.platformEncodingId == NameRecord.encodingWindowsUnicodeBmp &&
        record.languageId == NameRecord.languageWindowsEnUs &&
        record.nameId >= 0 &&
        record.nameId < 7;
  }

  List<int> _encodeNameString(String value, int platform, int encoding) {
    if (platform == CmapTable.platformWindows &&
        encoding == CmapTable.encodingWinUnicodeBmp) {
      return _encodeUtf16(value);
    }
    if (platform == 2) {
      if (encoding == 0) {
        return ascii.encode(value);
      }
      if (encoding == 1) {
        return _encodeUtf16(value);
      }
    }
    return latin1.encode(value);
  }

  List<int> _encodeUtf16(String value) {
    final codeUnits = value.codeUnits;
    final bytes = Uint8List(codeUnits.length * 2);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < codeUnits.length; i++) {
      view.setUint16(i * 2, codeUnits[i], Endian.big);
    }
    return bytes;
  }

  void _writeSfntHeader(ByteData out, int tableCount) {
    out.setUint32(0, 0x00010000, Endian.big);
    out.setUint16(4, tableCount, Endian.big);
    final mask = tableCount == 0 ? 0 : 1 << _log2(tableCount);
    final searchRange = mask * 16;
    out.setUint16(6, searchRange, Endian.big);
    final entrySelector = mask == 0 ? 0 : _log2(mask);
    out.setUint16(8, entrySelector, Endian.big);
    final rangeShift = tableCount * 16 - searchRange;
    out.setUint16(10, rangeShift, Endian.big);
  }

  void _writeFixed(BytesBuilder out, double value) {
    final integerPart = value.floor();
    final fractionPart = ((value - integerPart) * 65536.0).round();
    _writeInt16(out, integerPart);
    _writeUint16(out, fractionPart);
  }

  void _writeUint32(BytesBuilder out, int value) {
    final bytes = ByteData(4)..setUint32(0, value & 0xffffffff, Endian.big);
    out.add(bytes.buffer.asUint8List());
  }

  void _writeUint16(BytesBuilder out, int value) {
    final bytes = ByteData(2)..setUint16(0, value & 0xffff, Endian.big);
    out.add(bytes.buffer.asUint8List());
  }

  void _writeInt16(BytesBuilder out, int value) {
    final bytes = ByteData(2)..setInt16(0, value, Endian.big);
    out.add(bytes.buffer.asUint8List());
  }

  void _writeUint8(BytesBuilder out, int value) {
    out.add(<int>[value & 0xff]);
  }

  void _writeLongDateTime(BytesBuilder out, DateTime? dateTime) {
    final date =
        (dateTime ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
            .toUtc();
    final secondsSinceEpoch = date.millisecondsSinceEpoch ~/ 1000;
    final secondsSince1904 = secondsSinceEpoch + _secondsBetween1904And1970;
    final bytes = ByteData(8)..setInt64(0, secondsSince1904, Endian.big);
    out.add(bytes.buffer.asUint8List());
  }

  Uint8List _tableView(Uint8List data, int offset, int length) {
    if (offset < 0) {
      offset = 0;
    }
    final safeLength =
        offset + length <= data.length ? length : data.length - offset;
    return Uint8List.view(data.buffer, data.offsetInBytes + offset, safeLength);
  }

  int _getNewGlyphId(int oldGid) {
    _ensureGlyphOrderCache();
    final gid = _oldToNewGidCache![oldGid];
    if (gid == null) {
      throw IOException('Internal error: glyph $oldGid not in glyph subset');
    }
    return gid;
  }

  void _ensureGlyphOrderCache() {
    if (_glyphIdListCache != null && _oldToNewGidCache != null) {
      return;
    }
    final list = List<int>.from(_glyphIds);
    final map = <int, int>{};
    for (var index = 0; index < list.length; index++) {
      map[list[index]] = index;
    }
    _glyphIdListCache = list;
    _oldToNewGidCache = map;
  }

  void _invalidateGlyphCaches() {
    _glyphIdListCache = null;
    _oldToNewGidCache = null;
  }

  int _computeChecksum(Uint8List data) {
    var sum = 0;
    var i = 0;
    while (i + 3 < data.length) {
      sum = (sum +
              ((data[i] & 0xff) << 24) +
              ((data[i + 1] & 0xff) << 16) +
              ((data[i + 2] & 0xff) << 8) +
              (data[i + 3] & 0xff)) &
          0xffffffff;
      i += 4;
    }
    if (i < data.length) {
      var word = 0;
      var shift = 24;
      while (i < data.length && shift >= 0) {
        word |= (data[i] & 0xff) << shift;
        i++;
        shift -= 8;
      }
      sum = (sum + word) & 0xffffffff;
    }
    return sum;
  }

  int _paddedLength(int length) => (length + 3) & ~3;

  int _highestPowerOf2(int value) {
    if (value <= 0) {
      return 0;
    }
    var power = 1;
    while (power * 2 <= value) {
      power *= 2;
    }
    return power;
  }

  int _log2(int value) {
    if (value <= 0) {
      return 0;
    }
    var result = 0;
    var temp = value;
    while (temp > 1) {
      temp >>= 1;
      result++;
    }
    return result;
  }

  void _writeTag(Uint8List buffer, int offset, String tag) {
    final bytes = latin1.encode(tag);
    for (var i = 0; i < 4 && i < bytes.length; i++) {
      buffer[offset + i] = bytes[i];
    }
  }
}

class _TableRecord {
  _TableRecord({
    required this.tag,
    required this.data,
    required this.checksum,
    required this.offset,
    required this.length,
  });

  final String tag;
  final Uint8List data;
  final int checksum;
  final int offset;
  final int length;
}
