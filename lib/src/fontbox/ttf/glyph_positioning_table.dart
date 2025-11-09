import 'dart:collection';

import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import '../io/ttf_data_stream.dart';
import 'table/common/coverage_table.dart';
import 'table/common/coverage_table_format1.dart';
import 'table/common/coverage_table_format2.dart';
import 'table/common/feature_variation_evaluator.dart';
import 'table/common/feature_list_table.dart';
import 'table/common/feature_record.dart';
import 'table/common/feature_table.dart';
import 'table/common/feature_variations.dart';
import 'table/common/lang_sys_table.dart';
import 'table/common/lookup_list_table.dart';
import 'table/common/lookup_sub_table.dart';
import 'table/common/lookup_table.dart';
import 'table/common/range_record.dart';
import 'table/common/script_table.dart';
import 'table/gpos/anchor_table.dart';
import 'table/gpos/class_def_table.dart';
import 'table/gpos/pair_value_record.dart';
import 'table/gpos/value_record.dart';
import 'ttf_table.dart';
import 'variation/variation_coordinate_provider.dart';
import 'open_type_script.dart';
import 'jstf/jstf_lookup_control.dart';

/// Glyph positioning ('GPOS') table implementation providing kerning and placement data.
class GlyphPositioningTable extends TtfTable {
  GlyphPositioningTable();

  static final Logger _log = Logger('fontbox.GlyphPositioningTable');
  static const String tableTag = 'GPOS';

  Map<String, ScriptTable> _scriptList = const <String, ScriptTable>{};
  FeatureListTable? _featureListTable;
  LookupListTable? _lookupListTable;
  final Map<int, _LookupContributions> _lookupContributions =
      <int, _LookupContributions>{};
  bool _hasFeatureVariations = false;
  List<FeatureVariationRecord> _featureVariations =
      const <FeatureVariationRecord>[];

  final Map<int, ValueRecord> _singleAdjustments = <int, ValueRecord>{};
  final Map<int, Map<int, PairValueRecord>> _pairAdjustments =
      <int, Map<int, PairValueRecord>>{};
  final List<_ClassPairAdjustment> _classPairAdjustments =
      <_ClassPairAdjustment>[];
  final Map<int, _CursiveAttachment> _cursiveAttachments =
      <int, _CursiveAttachment>{};
  final List<_MarkToBaseAttachment> _markToBaseAttachments =
      <_MarkToBaseAttachment>[];
  final List<_MarkToLigatureAttachment> _markToLigatureAttachments =
      <_MarkToLigatureAttachment>[];
  final List<_MarkToMarkAttachment> _markToMarkAttachments =
      <_MarkToMarkAttachment>[];

  Map<String, ScriptTable> get scriptList => _scriptList;
  FeatureListTable? get featureListTable => _featureListTable;
  LookupListTable? get lookupListTable => _lookupListTable;
  bool get hasFeatureVariations => _hasFeatureVariations;
  List<FeatureVariationRecord> get featureVariations => _featureVariations;

  /// Creates an executor capable of applying the collected GPOS adjustments.
  GlyphPositioningExecutor createExecutor() => GlyphPositioningExecutor(this);

  bool get hasAdjustments =>
      _singleAdjustments.isNotEmpty ||
      _pairAdjustments.isNotEmpty ||
      _classPairAdjustments.isNotEmpty ||
      _cursiveAttachments.isNotEmpty ||
      _markToBaseAttachments.isNotEmpty ||
      _markToLigatureAttachments.isNotEmpty ||
      _markToMarkAttachments.isNotEmpty;

  ValueRecord? getSingleAdjustment(int glyphId) => _singleAdjustments[glyphId];

  PairValueRecord? getPairAdjustment(int firstGlyphId, int secondGlyphId) {
    final pairs = _pairAdjustments[firstGlyphId];
    if (pairs != null) {
      final direct = pairs[secondGlyphId];
      if (direct != null) {
        return direct;
      }
    }
    for (final classAdjustment in _classPairAdjustments) {
      final record = classAdjustment.resolve(firstGlyphId, secondGlyphId);
      if (record != null) {
        return record;
      }
    }
    return null;
  }

  int getKerningValue(int leftGlyphId, int rightGlyphId) {
    final adjustment = getPairAdjustment(leftGlyphId, rightGlyphId);
    if (adjustment == null) {
      return 0;
    }
    return adjustment.valueRecord1.xAdvance;
  }

  @override
  void read(dynamic ttf, TtfDataStream data) {
    final tableStart = data.currentPosition;
    final majorVersion = data.readUnsignedShort();
    if (majorVersion != 1) {
      _log.warning('Unsupported GPOS major version $majorVersion');
    }
    final minorVersion = data.readUnsignedShort();
    final scriptListOffset = data.readUnsignedShort();
    final featureListOffset = data.readUnsignedShort();
    final lookupListOffset = data.readUnsignedShort();

    _singleAdjustments.clear();
    _pairAdjustments.clear();
    _classPairAdjustments.clear();
    _cursiveAttachments.clear();
    _markToBaseAttachments.clear();
    _markToLigatureAttachments.clear();
    _markToMarkAttachments.clear();
    _lookupContributions.clear();

    List<FeatureVariationRecord> featureVariations =
        const <FeatureVariationRecord>[];
    if (minorVersion > 0) {
      final featureVariationsOffset = data.readUnsignedInt();
      if (featureVariationsOffset != 0) {
        featureVariations =
            readFeatureVariations(data, tableStart + featureVariationsOffset);
      }
    }
    _featureVariations = featureVariations;
    _hasFeatureVariations = featureVariations.isNotEmpty;

    _scriptList = scriptListOffset > 0
        ? _readScriptList(data, tableStart + scriptListOffset)
        : const <String, ScriptTable>{};
    _featureListTable = featureListOffset > 0
        ? _readFeatureList(data, tableStart + featureListOffset)
        : FeatureListTable(0, const <FeatureRecord>[]);
    if (_featureListTable != null && featureVariations.isNotEmpty) {
      final axisCoordinates = ttf is VariationCoordinateProvider
          ? ttf.normalizedVariationCoordinates
          : const <double>[];
      _featureListTable = _applyFeatureVariations(
        data,
        _featureListTable!,
        featureVariations,
        axisCoordinates,
      );
    }
    _lookupListTable = lookupListOffset > 0
        ? _readLookupList(data, tableStart + lookupListOffset)
        : LookupListTable(0, const <LookupTable>[]);

    setInitialized(true);
  }

  Map<String, ScriptTable> _readScriptList(TtfDataStream data, int offset) {
    data.seek(offset);
    final scriptCount = data.readUnsignedShort();
    final scriptOffsets = List<int>.filled(scriptCount, 0);
    final scriptTags = List<String>.filled(scriptCount, '');
    for (var i = 0; i < scriptCount; i++) {
      scriptTags[i] = data.readString(4);
      scriptOffsets[i] = data.readUnsignedShort();
      if (i > 0 && scriptTags[i].compareTo(scriptTags[i - 1]) < 0) {
        _log.fine(
            'Script tags appear unsorted: ${scriptTags[i]} < ${scriptTags[i - 1]}');
      }
    }

    final scripts = LinkedHashMap<String, ScriptTable>();
    for (var i = 0; i < scriptCount; i++) {
      final scriptOffset = scriptOffsets[i];
      if (scriptOffset == 0) {
        _log.fine('Script offset for tag ${scriptTags[i]} is zero, skipping');
        continue;
      }
      scripts[scriptTags[i]] = _readScriptTable(data, offset + scriptOffset);
    }
    return Map<String, ScriptTable>.unmodifiable(scripts);
  }

  ScriptTable _readScriptTable(TtfDataStream data, int offset) {
    data.seek(offset);
    final defaultLangSysOffset = data.readUnsignedShort();
    final langSysCount = data.readUnsignedShort();
    final langSysTags = List<String>.filled(langSysCount, '');
    final langSysOffsets = List<int>.filled(langSysCount, 0);
    for (var i = 0; i < langSysCount; i++) {
      langSysTags[i] = data.readString(4);
      langSysOffsets[i] = data.readUnsignedShort();
    }

    LangSysTable? defaultLangSys;
    if (defaultLangSysOffset != 0) {
      defaultLangSys = _readLangSysTable(data, offset + defaultLangSysOffset);
    }

    final langSystems = LinkedHashMap<String, LangSysTable>();
    for (var i = 0; i < langSysCount; i++) {
      final langSysOffset = langSysOffsets[i];
      if (langSysOffset == 0) {
        _log.fine(
            'Language system offset for tag ${langSysTags[i]} is zero, skipping');
        continue;
      }
      langSystems[langSysTags[i]] =
          _readLangSysTable(data, offset + langSysOffset);
    }

    return ScriptTable(defaultLangSys, langSystems);
  }

  LangSysTable _readLangSysTable(TtfDataStream data, int offset) {
    data.seek(offset);
    final lookupOrder = data.readUnsignedShort();
    final requiredFeatureIndex = data.readUnsignedShort();
    final featureIndexCount = data.readUnsignedShort();
    final featureIndices = data.readUnsignedShortArray(featureIndexCount);
    return LangSysTable(
        lookupOrder, requiredFeatureIndex, featureIndexCount, featureIndices);
  }

  FeatureListTable _readFeatureList(TtfDataStream data, int offset) {
    data.seek(offset);
    final featureCount = data.readUnsignedShort();
    final featureOffsets = List<int>.filled(featureCount, 0);
    final featureTags = List<String>.filled(featureCount, '');
    for (var i = 0; i < featureCount; i++) {
      featureTags[i] = data.readString(4);
      featureOffsets[i] = data.readUnsignedShort();
    }

    final records = List<FeatureRecord>.generate(featureCount, (index) {
      final featureOffset = featureOffsets[index];
      final recordOffset = offset + featureOffset;
      final table = _readFeatureTable(data, recordOffset);
      return FeatureRecord(featureTags[index], table);
    });
    return FeatureListTable(featureCount, records);
  }

  FeatureTable _readFeatureTable(TtfDataStream data, int offset) {
    data.seek(offset);
    final featureParams = data.readUnsignedShort();
    final lookupIndexCount = data.readUnsignedShort();
    final lookupIndices = data.readUnsignedShortArray(lookupIndexCount);
    return FeatureTable(featureParams, lookupIndexCount, lookupIndices);
  }

  LookupListTable _readLookupList(TtfDataStream data, int offset) {
    data.seek(offset);
    final lookupCount = data.readUnsignedShort();
    final lookupOffsets = List<int>.filled(lookupCount, 0);
    for (var i = 0; i < lookupCount; i++) {
      lookupOffsets[i] = data.readUnsignedShort();
    }

    final lookups = List<LookupTable>.generate(lookupCount, (index) {
      final lookupOffset = lookupOffsets[index];
      final contributions =
          _lookupContributions.putIfAbsent(index, () => _LookupContributions());
      return _readLookupTable(data, offset + lookupOffset, index, contributions);
    });
    return LookupListTable(lookupCount, lookups);
  }

  LookupTable _readLookupTable(
    TtfDataStream data,
    int offset,
    int lookupIndex,
    _LookupContributions contributions,
  ) {
    data.seek(offset);
    final lookupType = data.readUnsignedShort();
    final lookupFlag = data.readUnsignedShort();
    final subTableCount = data.readUnsignedShort();
    final subTableOffsets = data.readUnsignedShortArray(subTableCount);
    var markFilteringSet = 0;
    if ((lookupFlag & 0x0010) != 0) {
      markFilteringSet = data.readUnsignedShort();
    }

    for (var i = 0; i < subTableCount; i++) {
      final subtableOffset = subTableOffsets[i];
      if (lookupType == 7) {
        _log.fine('Ignoring extension lookup type in GPOS');
        continue;
      }
      if (subtableOffset == 0) {
        continue;
      }
      _collectLookupSubtable(
        data,
        offset + subtableOffset,
        lookupType,
        contributions,
      );
    }

    return LookupTable(
        lookupType, lookupFlag, markFilteringSet, const <LookupSubTable>[]);
  }

  void _collectLookupSubtable(
    TtfDataStream data,
    int offset,
    int lookupType,
    _LookupContributions contributions,
  ) {
    switch (lookupType) {
      case 1:
        _collectSinglePos(data, offset, contributions);
        break;
      case 2:
        _collectPairPos(data, offset, contributions);
        break;
      case 3:
        _collectCursivePos(data, offset, contributions);
        break;
      case 4:
        _collectMarkToBasePos(data, offset, contributions);
        break;
      case 5:
        _collectMarkToLigaturePos(data, offset, contributions);
        break;
      case 6:
        _collectMarkToMarkPos(data, offset, contributions);
        break;
      default:
        _log.fine('Unsupported GPOS lookup type $lookupType');
        break;
    }
  }

  void _collectSinglePos(
      TtfDataStream data, int offset, _LookupContributions contributions) {
    data.seek(offset);
    final posFormat = data.readUnsignedShort();
    final coverageOffset = data.readUnsignedShort();
    final valueFormat = data.readUnsignedShort();

    final coverage = _readCoverageTable(data, offset + coverageOffset);
    if (posFormat == 1) {
      final valueRecord = ValueRecord.read(data, valueFormat);
      for (var i = 0; i < coverage.getSize(); i++) {
        final glyphId = coverage.getGlyphId(i);
        _singleAdjustments[glyphId] = valueRecord;
        contributions.singleAdjustments[glyphId] = valueRecord;
      }
      return;
    }

    if (posFormat == 2) {
      final valueCount = data.readUnsignedShort();
      final values = List<ValueRecord>.generate(
          valueCount, (_) => ValueRecord.read(data, valueFormat));
      final coverageSize = coverage.getSize();
      if (coverageSize != valueCount) {
        _log.warning(
            'SinglePos format2 coverage size $coverageSize != valueCount $valueCount');
      }
      final limit = coverageSize < valueCount ? coverageSize : valueCount;
      for (var i = 0; i < limit; i++) {
        final glyphId = coverage.getGlyphId(i);
        final record = values[i];
        _singleAdjustments[glyphId] = record;
        contributions.singleAdjustments[glyphId] = record;
      }
      return;
    }

    _log.fine('Unsupported SinglePos format $posFormat');
  }

  void _collectPairPos(
      TtfDataStream data, int offset, _LookupContributions contributions) {
    data.seek(offset);
    final posFormat = data.readUnsignedShort();
    final coverageOffset = data.readUnsignedShort();
    final valueFormat1 = data.readUnsignedShort();
    final valueFormat2 = data.readUnsignedShort();

    final coverage = _readCoverageTable(data, offset + coverageOffset);

    if (posFormat == 1) {
      final pairSetCount = data.readUnsignedShort();
      final pairSetOffsets = data.readUnsignedShortArray(pairSetCount);
      final coverageSize = coverage.getSize();
      if (coverageSize != pairSetCount) {
        _log.fine(
            'PairPos format1 coverage size $coverageSize != pairSetCount $pairSetCount');
      }
      final limit = pairSetCount < coverageSize ? pairSetCount : coverageSize;
      for (var i = 0; i < limit; i++) {
        final pairSetOffset = pairSetOffsets[i];
        if (pairSetOffset == 0) {
          continue;
        }
        data.seek(offset + pairSetOffset);
        final pairValueCount = data.readUnsignedShort();
        for (var j = 0; j < pairValueCount; j++) {
          final record = PairValueRecord.read(data, valueFormat1, valueFormat2);
          final firstGlyph = coverage.getGlyphId(i);
          final pairs = _pairAdjustments.putIfAbsent(
              firstGlyph, () => <int, PairValueRecord>{});
          pairs[record.secondGlyph] = record;
          final lookupPairs = contributions.pairAdjustments.putIfAbsent(
              firstGlyph, () => <int, PairValueRecord>{});
          lookupPairs[record.secondGlyph] = record;
        }
      }
      return;
    }

    if (posFormat == 2) {
      final classDef1Offset = data.readUnsignedShort();
      final classDef2Offset = data.readUnsignedShort();
      final class1Count = data.readUnsignedShort();
      final class2Count = data.readUnsignedShort();

      if (classDef1Offset == 0 || classDef2Offset == 0) {
        _log.fine('PairPos format2 missing class definition offsets');
        return;
      }

      final classDef1 = ClassDefTable.read(data, offset + classDef1Offset);
      final classDef2 = ClassDefTable.read(data, offset + classDef2Offset);

      final records = List<List<_ValueRecordPair>>.generate(
        class1Count,
        (_) => List<_ValueRecordPair>.filled(
          class2Count,
          _ValueRecordPair.zero,
          growable: false,
        ),
        growable: false,
      );

      for (var class1Index = 0; class1Index < class1Count; class1Index++) {
        for (var class2Index = 0; class2Index < class2Count; class2Index++) {
          final value1 = ValueRecord.read(data, valueFormat1);
          final value2 = ValueRecord.read(data, valueFormat2);
          records[class1Index][class2Index] = _ValueRecordPair(value1, value2);
        }
      }

      final classAdjustment = _ClassPairAdjustment(
        classDef1,
        classDef2,
        records,
      );
      _classPairAdjustments.add(classAdjustment);
      contributions.classPairAdjustments.add(classAdjustment);
      return;
    }

    _log.fine('Unsupported PairPos format $posFormat');
  }

  void _collectCursivePos(
      TtfDataStream data, int offset, _LookupContributions contributions) {
    data.seek(offset);
    final posFormat = data.readUnsignedShort();
    if (posFormat != 1) {
      _log.fine('Unsupported CursivePos format $posFormat');
      return;
    }
    final coverageOffset = data.readUnsignedShort();
    final entryExitCount = data.readUnsignedShort();
    final entryOffsets = List<int>.filled(entryExitCount, 0);
    final exitOffsets = List<int>.filled(entryExitCount, 0);
    for (var i = 0; i < entryExitCount; i++) {
      entryOffsets[i] = data.readUnsignedShort();
      exitOffsets[i] = data.readUnsignedShort();
    }

    final coverage = _readCoverageTable(data, offset + coverageOffset);
    final coverageSize = coverage.getSize();
    if (coverageSize != entryExitCount) {
      _log.fine(
          'CursivePos coverage size $coverageSize != entryExitCount $entryExitCount');
    }
    final limit = coverageSize < entryExitCount ? coverageSize : entryExitCount;
    for (var i = 0; i < limit; i++) {
      final entryOffset = entryOffsets[i];
      final exitOffset = exitOffsets[i];
      AnchorTable? entryAnchor;
      AnchorTable? exitAnchor;
      if (entryOffset != 0) {
        entryAnchor = AnchorTable.read(data, offset + entryOffset);
      }
      if (exitOffset != 0) {
        exitAnchor = AnchorTable.read(data, offset + exitOffset);
      }
      if (entryAnchor == null && exitAnchor == null) {
        continue;
      }
      final glyphId = coverage.getGlyphId(i);
      final attachment = _CursiveAttachment(entryAnchor, exitAnchor);
      _cursiveAttachments[glyphId] = attachment;
      contributions.cursiveAttachments[glyphId] = attachment;
    }
  }

  void _collectMarkToBasePos(
      TtfDataStream data, int offset, _LookupContributions contributions) {
    data.seek(offset);
    final posFormat = data.readUnsignedShort();
    if (posFormat != 1) {
      _log.fine('Unsupported MarkToBasePos format $posFormat');
      return;
    }
    final markCoverageOffset = data.readUnsignedShort();
    final baseCoverageOffset = data.readUnsignedShort();
    final classCount = data.readUnsignedShort();
    final markArrayOffset = data.readUnsignedShort();
    final baseArrayOffset = data.readUnsignedShort();
    if (classCount == 0) {
      return;
    }

    final markCoverage = _readCoverageTable(data, offset + markCoverageOffset);
    final baseCoverage = _readCoverageTable(data, offset + baseCoverageOffset);

    final markRecords =
        _readMarkArray(data, offset + markArrayOffset, markCoverage.getSize());
    final baseRecords =
        _readBaseArray(data, offset + baseArrayOffset, classCount);

    final markMap = <int, _MarkGlyphRecord>{};
    final markLimit = markCoverage.getSize() < markRecords.length
        ? markCoverage.getSize()
        : markRecords.length;
    for (var i = 0; i < markLimit; i++) {
      final glyphId = markCoverage.getGlyphId(i);
      final record = markRecords[i];
      if (record.anchor == null) {
        continue;
      }
      markMap[glyphId] = _MarkGlyphRecord(record.markClass, record.anchor!);
    }

    final baseMap = <int, List<AnchorTable?>>{};
    final baseLimit = baseCoverage.getSize() < baseRecords.length
        ? baseCoverage.getSize()
        : baseRecords.length;
    for (var i = 0; i < baseLimit; i++) {
      final glyphId = baseCoverage.getGlyphId(i);
      baseMap[glyphId] = baseRecords[i];
    }

    if (markMap.isNotEmpty && baseMap.isNotEmpty) {
      final attachment =
          _MarkToBaseAttachment(markMap, baseMap, classCount);
      _markToBaseAttachments.add(attachment);
      contributions.markToBaseAttachments.add(attachment);
    }
  }

  void _collectMarkToLigaturePos(
      TtfDataStream data, int offset, _LookupContributions contributions) {
    data.seek(offset);
    final posFormat = data.readUnsignedShort();
    if (posFormat != 1) {
      _log.fine('Unsupported MarkToLigaturePos format $posFormat');
      return;
    }
    final markCoverageOffset = data.readUnsignedShort();
    final ligatureCoverageOffset = data.readUnsignedShort();
    final classCount = data.readUnsignedShort();
    final markArrayOffset = data.readUnsignedShort();
    final ligatureArrayOffset = data.readUnsignedShort();
    if (classCount == 0) {
      return;
    }

    final markCoverage = _readCoverageTable(data, offset + markCoverageOffset);
    final ligatureCoverage =
        _readCoverageTable(data, offset + ligatureCoverageOffset);

    final markRecords =
        _readMarkArray(data, offset + markArrayOffset, markCoverage.getSize());
    final ligatureRecords =
        _readLigatureArray(data, offset + ligatureArrayOffset, classCount);

    final markMap = <int, _MarkGlyphRecord>{};
    final markLimit = markCoverage.getSize() < markRecords.length
        ? markCoverage.getSize()
        : markRecords.length;
    for (var i = 0; i < markLimit; i++) {
      final glyphId = markCoverage.getGlyphId(i);
      final record = markRecords[i];
      if (record.anchor == null) {
        continue;
      }
      markMap[glyphId] = _MarkGlyphRecord(record.markClass, record.anchor!);
    }

    final ligatureMap = <int, List<List<AnchorTable?>>>{};
    final ligatureLimit = ligatureCoverage.getSize() < ligatureRecords.length
        ? ligatureCoverage.getSize()
        : ligatureRecords.length;
    for (var i = 0; i < ligatureLimit; i++) {
      final glyphId = ligatureCoverage.getGlyphId(i);
      ligatureMap[glyphId] = ligatureRecords[i];
    }

    if (markMap.isNotEmpty && ligatureMap.isNotEmpty) {
      final attachment =
          _MarkToLigatureAttachment(markMap, ligatureMap, classCount);
      _markToLigatureAttachments.add(attachment);
      contributions.markToLigatureAttachments.add(attachment);
    }
  }

  void _collectMarkToMarkPos(
      TtfDataStream data, int offset, _LookupContributions contributions) {
    data.seek(offset);
    final posFormat = data.readUnsignedShort();
    if (posFormat != 1) {
      _log.fine('Unsupported MarkToMarkPos format $posFormat');
      return;
    }
    final mark1CoverageOffset = data.readUnsignedShort();
    final mark2CoverageOffset = data.readUnsignedShort();
    final classCount = data.readUnsignedShort();
    final mark1ArrayOffset = data.readUnsignedShort();
    final mark2ArrayOffset = data.readUnsignedShort();
    if (classCount == 0) {
      return;
    }

    final mark1Coverage =
        _readCoverageTable(data, offset + mark1CoverageOffset);
    final mark2Coverage =
        _readCoverageTable(data, offset + mark2CoverageOffset);

    final mark1Records = _readMarkArray(
        data, offset + mark1ArrayOffset, mark1Coverage.getSize());
    final mark2Records =
        _readMark2Array(data, offset + mark2ArrayOffset, classCount);

    final mark1Map = <int, _MarkGlyphRecord>{};
    final mark1Limit = mark1Coverage.getSize() < mark1Records.length
        ? mark1Coverage.getSize()
        : mark1Records.length;
    for (var i = 0; i < mark1Limit; i++) {
      final glyphId = mark1Coverage.getGlyphId(i);
      final record = mark1Records[i];
      if (record.anchor == null) {
        continue;
      }
      mark1Map[glyphId] = _MarkGlyphRecord(record.markClass, record.anchor!);
    }

    final mark2Map = <int, List<AnchorTable?>>{};
    final mark2Limit = mark2Coverage.getSize() < mark2Records.length
        ? mark2Coverage.getSize()
        : mark2Records.length;
    for (var i = 0; i < mark2Limit; i++) {
      final glyphId = mark2Coverage.getGlyphId(i);
      mark2Map[glyphId] = mark2Records[i];
    }

    if (mark1Map.isNotEmpty && mark2Map.isNotEmpty) {
      final attachment =
          _MarkToMarkAttachment(mark1Map, mark2Map, classCount);
      _markToMarkAttachments.add(attachment);
      contributions.markToMarkAttachments.add(attachment);
    }
  }

  List<_MarkArrayEntry> _readMarkArray(
    TtfDataStream data,
    int offset,
    int expectedCount,
  ) {
    data.seek(offset);
    final markCount = data.readUnsignedShort();
    final classValues = List<int>.filled(markCount, 0);
    final anchorOffsets = List<int>.filled(markCount, 0);
    for (var i = 0; i < markCount; i++) {
      classValues[i] = data.readUnsignedShort();
      anchorOffsets[i] = data.readUnsignedShort();
    }
    final entries = List<_MarkArrayEntry>.generate(markCount, (index) {
      final anchorOffset = anchorOffsets[index];
      final anchor = anchorOffset == 0
          ? null
          : AnchorTable.read(data, offset + anchorOffset);
      return _MarkArrayEntry(classValues[index], anchor);
    }, growable: false);
    if (markCount != expectedCount) {
      _log.fine('MarkArray count $markCount != coverage size $expectedCount');
    }
    return entries;
  }

  List<List<AnchorTable?>> _readBaseArray(
    TtfDataStream data,
    int offset,
    int classCount,
  ) {
    data.seek(offset);
    final baseCount = data.readUnsignedShort();
    final anchorOffsets = List<List<int>>.generate(
      baseCount,
      (_) => data.readUnsignedShortArray(classCount),
      growable: false,
    );
    return List<List<AnchorTable?>>.generate(baseCount, (baseIndex) {
      final anchors =
          List<AnchorTable?>.filled(classCount, null, growable: false);
      for (var classIndex = 0; classIndex < classCount; classIndex++) {
        final anchorOffset = anchorOffsets[baseIndex][classIndex];
        if (anchorOffset != 0) {
          anchors[classIndex] = AnchorTable.read(data, offset + anchorOffset);
        }
      }
      return anchors;
    }, growable: false);
  }

  List<List<List<AnchorTable?>>> _readLigatureArray(
    TtfDataStream data,
    int offset,
    int classCount,
  ) {
    data.seek(offset);
    final ligatureCount = data.readUnsignedShort();
    final ligatureOffsets = data.readUnsignedShortArray(ligatureCount);
    return List<List<List<AnchorTable?>>>.generate(ligatureCount, (index) {
      final attachOffset = ligatureOffsets[index];
      if (attachOffset == 0) {
        return const <List<AnchorTable?>>[];
      }
      final attachBase = offset + attachOffset;
      data.seek(attachBase);
      final componentCount = data.readUnsignedShort();
      return List<List<AnchorTable?>>.generate(componentCount, (_) {
        final anchors =
            List<AnchorTable?>.filled(classCount, null, growable: false);
        for (var classIndex = 0; classIndex < classCount; classIndex++) {
          final anchorOffset = data.readUnsignedShort();
          if (anchorOffset != 0) {
            anchors[classIndex] =
                AnchorTable.read(data, attachBase + anchorOffset);
          }
        }
        return anchors;
      }, growable: false);
    }, growable: false);
  }

  List<List<AnchorTable?>> _readMark2Array(
    TtfDataStream data,
    int offset,
    int classCount,
  ) {
    data.seek(offset);
    final mark2Count = data.readUnsignedShort();
    final anchorOffsets = List<List<int>>.generate(
      mark2Count,
      (_) => data.readUnsignedShortArray(classCount),
      growable: false,
    );
    return List<List<AnchorTable?>>.generate(mark2Count, (mark2Index) {
      final anchors =
          List<AnchorTable?>.filled(classCount, null, growable: false);
      for (var classIndex = 0; classIndex < classCount; classIndex++) {
        final anchorOffset = anchorOffsets[mark2Index][classIndex];
        if (anchorOffset != 0) {
          anchors[classIndex] = AnchorTable.read(data, offset + anchorOffset);
        }
      }
      return anchors;
    }, growable: false);
  }

  FeatureListTable _applyFeatureVariations(
    TtfDataStream data,
    FeatureListTable featureList,
    List<FeatureVariationRecord> variations,
    List<double> axisCoordinates,
  ) {
    var current = featureList;
    final evaluator = FeatureVariationEvaluator(axisCoordinates);
    for (final variation in variations) {
      if (!evaluator.matches(variation)) {
        continue;
      }
      final substitutionOffset = variation.featureTableSubstitutionOffset;
      if (substitutionOffset == 0) {
        continue;
      }
      current = _applyFeatureTableSubstitution(
        data,
        current,
        substitutionOffset,
      );
    }
    return current;
  }

  FeatureListTable _applyFeatureTableSubstitution(
    TtfDataStream data,
    FeatureListTable featureList,
    int substitutionOffset,
  ) {
    final saved = data.currentPosition;
    data.seek(substitutionOffset);
    final substitutionCount = data.readUnsignedShort();
    final featureIndices = List<int>.filled(substitutionCount, 0);
    final alternateOffsets = List<int>.filled(substitutionCount, 0);
    for (var i = 0; i < substitutionCount; i++) {
      featureIndices[i] = data.readUnsignedShort();
      alternateOffsets[i] = data.readUnsignedShort();
    }

    final updated = List<FeatureRecord>.from(featureList.featureRecords);
    for (var i = 0; i < substitutionCount; i++) {
      final featureIndex = featureIndices[i];
      if (featureIndex >= updated.length) {
        continue;
      }
      final alternateOffset = alternateOffsets[i];
      if (alternateOffset == 0) {
        continue;
      }
      final alternateFeatureOffset = substitutionOffset + alternateOffset;
      final alternateTable = _readFeatureTable(data, alternateFeatureOffset);
      final existing = updated[featureIndex];
      updated[featureIndex] = FeatureRecord(
        existing.featureTag,
        alternateTable,
      );
    }

    data.seek(saved);
    return FeatureListTable(featureList.featureCount, updated);
  }

  CoverageTable _readCoverageTable(TtfDataStream data, int offset) {
    final saved = data.currentPosition;
    data.seek(offset);
    final coverageFormat = data.readUnsignedShort();
    switch (coverageFormat) {
      case 1:
        {
          final glyphCount = data.readUnsignedShort();
          final glyphArray = data.readUnsignedShortArray(glyphCount);
          data.seek(saved);
          return CoverageTableFormat1(coverageFormat, glyphArray);
        }
      case 2:
        {
          final rangeCount = data.readUnsignedShort();
          final ranges = List<RangeRecord>.generate(rangeCount, (_) {
            final startGlyphId = data.readUnsignedShort();
            final endGlyphId = data.readUnsignedShort();
            final startCoverageIndex = data.readUnsignedShort();
            return RangeRecord(startGlyphId, endGlyphId, startCoverageIndex);
          });
          data.seek(saved);
          return CoverageTableFormat2(coverageFormat, ranges);
        }
      default:
        data.seek(saved);
        throw IOException('Unknown coverage format $coverageFormat');
    }
  }
}

class _ValueRecordPair {
  _ValueRecordPair(this.valueRecord1, this.valueRecord2);

  static final _ValueRecordPair zero =
      _ValueRecordPair(ValueRecord(), ValueRecord());

  final ValueRecord valueRecord1;
  final ValueRecord valueRecord2;

  bool get isZero => valueRecord1.isZero && valueRecord2.isZero;
}

class _ClassPairAdjustment {
  _ClassPairAdjustment(this.classDef1, this.classDef2, this.records);

  final ClassDefTable classDef1;
  final ClassDefTable classDef2;
  final List<List<_ValueRecordPair>> records;

  PairValueRecord? resolve(int firstGlyphId, int secondGlyphId) {
    final class1 = classDef1.getClass(firstGlyphId);
    if (class1 < 0 || class1 >= records.length) {
      return null;
    }
    final class2 = classDef2.getClass(secondGlyphId);
    if (class2 < 0 || class2 >= records[class1].length) {
      return null;
    }
    final pair = records[class1][class2];
    if (pair.isZero) {
      return null;
    }
    return PairValueRecord(secondGlyphId, pair.valueRecord1, pair.valueRecord2);
  }
}

class _CursiveAttachment {
  const _CursiveAttachment(this.entryAnchor, this.exitAnchor);

  final AnchorTable? entryAnchor;
  final AnchorTable? exitAnchor;

  bool get hasEntry => entryAnchor != null;
  bool get hasExit => exitAnchor != null;
}

class _MarkArrayEntry {
  _MarkArrayEntry(this.markClass, this.anchor);

  final int markClass;
  final AnchorTable? anchor;
}

class _MarkGlyphRecord {
  _MarkGlyphRecord(this.markClass, this.anchor);

  final int markClass;
  final AnchorTable anchor;
}

class _MarkToBaseAttachment {
  _MarkToBaseAttachment(this.markRecords, this.baseRecords, this.classCount);

  final Map<int, _MarkGlyphRecord> markRecords;
  final Map<int, List<AnchorTable?>> baseRecords;
  final int classCount;
}

class _MarkToLigatureAttachment {
  _MarkToLigatureAttachment(
      this.markRecords, this.ligatureRecords, this.classCount);

  final Map<int, _MarkGlyphRecord> markRecords;
  final Map<int, List<List<AnchorTable?>>> ligatureRecords;
  final int classCount;
}

class _MarkToMarkAttachment {
  _MarkToMarkAttachment(this.mark1Records, this.mark2Records, this.classCount);

  final Map<int, _MarkGlyphRecord> mark1Records;
  final Map<int, List<AnchorTable?>> mark2Records;
  final int classCount;
}

class _LookupContributions {
  _LookupContributions();

  final Map<int, ValueRecord> singleAdjustments = <int, ValueRecord>{};
  final Map<int, Map<int, PairValueRecord>> pairAdjustments =
    <int, Map<int, PairValueRecord>>{};
  final List<_ClassPairAdjustment> classPairAdjustments =
    <_ClassPairAdjustment>[];
  final Map<int, _CursiveAttachment> cursiveAttachments =
    <int, _CursiveAttachment>{};
  final List<_MarkToBaseAttachment> markToBaseAttachments =
    <_MarkToBaseAttachment>[];
  final List<_MarkToLigatureAttachment> markToLigatureAttachments =
    <_MarkToLigatureAttachment>[];
  final List<_MarkToMarkAttachment> markToMarkAttachments =
    <_MarkToMarkAttachment>[];

  bool get isEmpty =>
    singleAdjustments.isEmpty &&
    pairAdjustments.isEmpty &&
    classPairAdjustments.isEmpty &&
    cursiveAttachments.isEmpty &&
    markToBaseAttachments.isEmpty &&
    markToLigatureAttachments.isEmpty &&
    markToMarkAttachments.isEmpty;
}

class GlyphPositioningAdjustment {
  GlyphPositioningAdjustment();

  int xPlacement = 0;
  int yPlacement = 0;
  int xAdvance = 0;
  int yAdvance = 0;

  bool get isZero =>
      xPlacement == 0 && yPlacement == 0 && xAdvance == 0 && yAdvance == 0;

  void addValueRecord(ValueRecord record) {
    xPlacement += record.xPlacement;
    yPlacement += record.yPlacement;
    xAdvance += record.xAdvance;
    yAdvance += record.yAdvance;
  }

  void addPlacement(int dx, int dy) {
    xPlacement += dx;
    yPlacement += dy;
  }

  ValueRecord toValueRecord() => ValueRecord(
        xPlacement: xPlacement,
        yPlacement: yPlacement,
        xAdvance: xAdvance,
        yAdvance: yAdvance,
      );
}

class GlyphPositioningExecutor {
  GlyphPositioningExecutor(this._table);

  final GlyphPositioningTable _table;

  List<GlyphPositioningAdjustment> apply(
    List<int> glyphIds, {
    List<String>? scriptTags,
    List<String>? enabledFeatures,
    JstfLookupControl? jstfControl,
  }) {
    if (glyphIds.isEmpty) {
      return const <GlyphPositioningAdjustment>[];
    }

    final adjustments = List<GlyphPositioningAdjustment>.generate(
      glyphIds.length,
      (_) => GlyphPositioningAdjustment(),
      growable: false,
    );

    final lookupIndices = _resolveLookupOrder(
      scriptTags ?? const <String>[],
      enabledFeatures,
      jstfControl,
    );

    for (final lookupIndex in lookupIndices) {
      final contributions = _table._lookupContributions[lookupIndex];
      if (contributions == null || contributions.isEmpty) {
        continue;
      }
      _applySingles(contributions.singleAdjustments, glyphIds, adjustments);
      _applyPairs(contributions, glyphIds, adjustments);
      _applyCursive(contributions, glyphIds, adjustments);
      _applyMarkToBase(contributions, glyphIds, adjustments);
      _applyMarkToLigature(contributions, glyphIds, adjustments);
      _applyMarkToMark(contributions, glyphIds, adjustments);
    }

    return List<GlyphPositioningAdjustment>.unmodifiable(adjustments);
  }

  List<int> _resolveLookupOrder(
    List<String> scriptTags,
    List<String>? enabledFeatures,
    JstfLookupControl? jstfControl,
  ) {
    final scriptTag = _selectScriptTag(scriptTags);
    final langSysTables = _getLangSysTables(scriptTag);
    if (langSysTables.isEmpty) {
      return const <int>[];
    }
    final featureRecords = _getFeatureRecords(langSysTables, enabledFeatures);
    if (featureRecords.isEmpty) {
      return const <int>[];
    }
    final ordered = <int>{};
    final lookupOrder = <int>[];
    for (final feature in featureRecords) {
      for (final index in feature.featureTable.lookupListIndices) {
        if (!_isLookupActive(index, jstfControl)) {
          continue;
        }
        if (ordered.add(index)) {
          lookupOrder.add(index);
        }
      }
    }
    return lookupOrder;
  }

  bool _isLookupActive(int index, JstfLookupControl? control) {
    if (control == null) {
      return true;
    }
    if (control.isGposLookupDisabled(index)) {
      return false;
    }
    if (!control.hasEnabledGposLookups) {
      return true;
    }
    return control.isGposLookupEnabled(index);
  }

  String _selectScriptTag(List<String> tags) {
    if (tags.isEmpty) {
      return OpenTypeScript.tagDefault;
    }
    final scripts = _table._scriptList;
    if (tags.length == 1) {
      final tag = tags.first;
      if ((tag == OpenTypeScript.inherited ||
              (tag == OpenTypeScript.tagDefault &&
                  !scripts.containsKey(tag))) &&
          scripts.isNotEmpty) {
        return scripts.keys.first;
      }
    }
    for (final tag in tags) {
      if (scripts.containsKey(tag)) {
        return tag;
      }
    }
    return tags.first;
  }

  Iterable<LangSysTable> _getLangSysTables(String scriptTag) {
    final scriptTable = _table._scriptList[scriptTag];
    if (scriptTable == null) {
      return const <LangSysTable>[];
    }
    final langSystems = <LangSysTable>[];
    langSystems.addAll(scriptTable.langSysTables.values);
    final defaultLangSys = scriptTable.defaultLangSysTable;
    if (defaultLangSys != null) {
      langSystems.add(defaultLangSys);
    }
    return langSystems;
  }

  List<FeatureRecord> _getFeatureRecords(
    Iterable<LangSysTable> langSysTables,
    List<String>? enabledFeatures,
  ) {
    final featureList = _table._featureListTable;
    if (featureList == null) {
      return const <FeatureRecord>[];
    }
    final result = <FeatureRecord>[];
    final featureRecords = featureList.featureRecords;
    for (final langSys in langSysTables) {
      final requiredIndex = langSys.requiredFeatureIndex;
      if (requiredIndex != 0xffff && requiredIndex < featureRecords.length) {
        result.add(featureRecords[requiredIndex]);
      }
      for (final index in langSys.featureIndices) {
        if (index >= featureRecords.length) {
          continue;
        }
        final record = featureRecords[index];
        if (enabledFeatures == null ||
            enabledFeatures.contains(record.featureTag)) {
          result.add(record);
        }
      }
    }

    if (enabledFeatures != null && result.length > 1) {
      result.sort((a, b) {
        final indexA = enabledFeatures.indexOf(a.featureTag);
        final indexB = enabledFeatures.indexOf(b.featureTag);
        return indexA.compareTo(indexB);
      });
    }

    return result;
  }

  void _applySingles(
    Map<int, ValueRecord> singles,
    List<int> glyphIds,
    List<GlyphPositioningAdjustment> adjustments,
  ) {
    if (singles.isEmpty) {
      return;
    }
    for (var i = 0; i < glyphIds.length; i++) {
      final record = singles[glyphIds[i]];
      if (record != null) {
        adjustments[i].addValueRecord(record);
      }
    }
  }

  void _applyPairs(
    _LookupContributions contributions,
    List<int> glyphIds,
    List<GlyphPositioningAdjustment> adjustments,
  ) {
    if (glyphIds.length < 2) {
      return;
    }
    for (var i = 0; i < glyphIds.length - 1; i++) {
      final left = glyphIds[i];
      final right = glyphIds[i + 1];
      PairValueRecord? record;
      final direct = contributions.pairAdjustments[left];
      if (direct != null) {
        record = direct[right];
      }
      if (record == null) {
        for (final classAdjustment in contributions.classPairAdjustments) {
          record = classAdjustment.resolve(left, right);
          if (record != null) {
            break;
          }
        }
      }
      if (record == null) {
        continue;
      }
      adjustments[i].addValueRecord(record.valueRecord1);
      adjustments[i + 1].addValueRecord(record.valueRecord2);
    }
  }

  void _applyCursive(
    _LookupContributions contributions,
    List<int> glyphIds,
    List<GlyphPositioningAdjustment> adjustments,
  ) {
    if (glyphIds.length < 2 || contributions.cursiveAttachments.isEmpty) {
      return;
    }
    for (var i = 0; i < glyphIds.length - 1; i++) {
      final firstAttachment =
          contributions.cursiveAttachments[glyphIds[i]];
      final secondAttachment =
          contributions.cursiveAttachments[glyphIds[i + 1]];
      if (firstAttachment == null ||
          secondAttachment == null ||
          !firstAttachment.hasExit ||
          !secondAttachment.hasEntry) {
        continue;
      }
      final exitAnchor = firstAttachment.exitAnchor!;
      final entryAnchor = secondAttachment.entryAnchor!;
      final dx = exitAnchor.xCoordinate - entryAnchor.xCoordinate;
      final dy = exitAnchor.yCoordinate - entryAnchor.yCoordinate;
      adjustments[i + 1].addPlacement(dx, dy);
    }
  }

  void _applyMarkToBase(
    _LookupContributions contributions,
    List<int> glyphIds,
    List<GlyphPositioningAdjustment> adjustments,
  ) {
    if (contributions.markToBaseAttachments.isEmpty) {
      return;
    }
    for (final attachment in contributions.markToBaseAttachments) {
      List<AnchorTable?>? baseAnchors;
      for (var i = 0; i < glyphIds.length; i++) {
        final glyph = glyphIds[i];
        final candidateBase = attachment.baseRecords[glyph];
        if (candidateBase != null) {
          baseAnchors = candidateBase;
        }
        final markRecord = attachment.markRecords[glyph];
        if (markRecord == null || baseAnchors == null) {
          continue;
        }
        final markClass = markRecord.markClass;
        if (markClass < 0 ||
            markClass >= attachment.classCount ||
            markClass >= baseAnchors.length) {
          continue;
        }
        final baseAnchor = baseAnchors[markClass];
        if (baseAnchor == null) {
          continue;
        }
        final markAnchor = markRecord.anchor;
        final dx = baseAnchor.xCoordinate - markAnchor.xCoordinate;
        final dy = baseAnchor.yCoordinate - markAnchor.yCoordinate;
        adjustments[i].addPlacement(dx, dy);
      }
    }
  }

  void _applyMarkToLigature(
    _LookupContributions contributions,
    List<int> glyphIds,
    List<GlyphPositioningAdjustment> adjustments,
  ) {
    if (contributions.markToLigatureAttachments.isEmpty) {
      return;
    }
    for (final attachment in contributions.markToLigatureAttachments) {
      List<List<AnchorTable?>>? componentAnchors;
      var componentIndex = 0;
      for (var i = 0; i < glyphIds.length; i++) {
        final glyph = glyphIds[i];
        final ligatureAnchors = attachment.ligatureRecords[glyph];
        if (ligatureAnchors != null && ligatureAnchors.isNotEmpty) {
          componentAnchors = ligatureAnchors;
          componentIndex = 0;
        }
        final markRecord = attachment.markRecords[glyph];
        if (markRecord == null || componentAnchors == null) {
          continue;
        }
        if (componentAnchors.isEmpty) {
          continue;
        }
        var safeIndex = componentIndex;
        if (safeIndex < 0) {
          safeIndex = 0;
        } else if (safeIndex >= componentAnchors.length) {
          safeIndex = componentAnchors.length - 1;
        }
        final component = componentAnchors[safeIndex];
        if (component.isEmpty) {
          continue;
        }
        final markClass = markRecord.markClass;
        if (markClass < 0 || markClass >= attachment.classCount) {
          continue;
        }
        if (markClass >= component.length) {
          continue;
        }
        final baseAnchor = component[markClass];
        if (baseAnchor == null) {
          continue;
        }
        final dx = baseAnchor.xCoordinate - markRecord.anchor.xCoordinate;
        final dy = baseAnchor.yCoordinate - markRecord.anchor.yCoordinate;
        adjustments[i].addPlacement(dx, dy);
        if (componentIndex + 1 < componentAnchors.length) {
          componentIndex++;
        }
      }
    }
  }

  void _applyMarkToMark(
    _LookupContributions contributions,
    List<int> glyphIds,
    List<GlyphPositioningAdjustment> adjustments,
  ) {
    if (contributions.markToMarkAttachments.isEmpty) {
      return;
    }
    for (final attachment in contributions.markToMarkAttachments) {
      List<AnchorTable?>? mark2Anchors;
      for (var i = 0; i < glyphIds.length; i++) {
        final glyph = glyphIds[i];
        final mark2 = attachment.mark2Records[glyph];
        if (mark2 != null) {
          mark2Anchors = mark2;
          continue;
        }
        final mark1 = attachment.mark1Records[glyph];
        if (mark1 == null || mark2Anchors == null) {
          continue;
        }
        final markClass = mark1.markClass;
        if (markClass < 0 ||
            markClass >= attachment.classCount ||
            markClass >= mark2Anchors.length) {
          continue;
        }
        final baseAnchor = mark2Anchors[markClass];
        if (baseAnchor == null) {
          continue;
        }
        final dx = baseAnchor.xCoordinate - mark1.anchor.xCoordinate;
        final dy = baseAnchor.yCoordinate - mark1.anchor.yCoordinate;
        adjustments[i].addPlacement(dx, dy);
      }
    }
  }
}
