import 'dart:collection';

import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import '../io/ttf_data_stream.dart';
import 'gsub/glyph_substitution_data_extractor.dart';
import 'model/gsub_data.dart';
import 'open_type_script.dart';
import 'table/common/coverage_table.dart';
import 'table/common/coverage_table_format1.dart';
import 'table/common/coverage_table_format2.dart';
import 'table/common/feature_list_table.dart';
import 'table/common/feature_record.dart';
import 'table/common/feature_table.dart';
import 'table/common/lang_sys_table.dart';
import 'table/common/lookup_list_table.dart';
import 'table/common/lookup_sub_table.dart';
import 'table/common/lookup_table.dart';
import 'table/common/range_record.dart';
import 'table/common/script_table.dart';
import 'table/gsub/alternate_set_table.dart';
import 'table/gsub/ligature_set_table.dart';
import 'table/gsub/ligature_table.dart';
import 'table/gsub/lookup_type_alternate_substitution_format1.dart';
import 'table/gsub/lookup_type_ligature_substitution_subst_format1.dart';
import 'table/gsub/lookup_type_multiple_substitution_format1.dart';
import 'table/gsub/lookup_type_single_subst_format1.dart';
import 'table/gsub/lookup_type_single_subst_format2.dart';
import 'table/gsub/sequence_table.dart';
import 'ttf_table.dart';

/// Glyph substitution ('GSUB') table implementation used for OpenType layout logic.
class GlyphSubstitutionTable extends TtfTable {
  GlyphSubstitutionTable();

  static final Logger _log = Logger('fontbox.GlyphSubstitutionTable');
  static const String tableTag = 'GSUB';
  static final RegExp _fourCharWord = RegExp(r'^\w{4}$');

  Map<String, ScriptTable> _scriptList = const <String, ScriptTable>{};
  FeatureListTable? _featureListTable;
  LookupListTable? _lookupListTable;

  final Map<int, int> _lookupCache = <int, int>{};
  final Map<int, int> _reverseLookup = <int, int>{};

  String? _lastUsedSupportedScript;
  GsubData? _gsubData;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    final tableStart = data.currentPosition;
    data.readUnsignedShort(); // majorVersion, unused for now
    final minorVersion = data.readUnsignedShort();
    final scriptListOffset = data.readUnsignedShort();
    final featureListOffset = data.readUnsignedShort();
    final lookupListOffset = data.readUnsignedShort();
    if (minorVersion == 1) {
      data.readUnsignedInt(); // featureVariationsOffset, unsupported
    }
    _scriptList = scriptListOffset > 0
        ? _readScriptList(data, tableStart + scriptListOffset)
        : const <String, ScriptTable>{};
    _featureListTable = featureListOffset > 0
        ? _readFeatureList(data, tableStart + featureListOffset)
        : FeatureListTable(0, const <FeatureRecord>[]);
    _lookupListTable = lookupListOffset > 0
        ? _readLookupList(data, tableStart + lookupListOffset)
        : LookupListTable(0, const <LookupTable>[]);

    final extractor = GlyphSubstitutionDataExtractor();
    _gsubData = extractor.getGsubData(
        _scriptList, _featureListTable!, _lookupListTable!);

    _lookupCache.clear();
    _reverseLookup.clear();
    _lastUsedSupportedScript = null;

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
    }

    final scripts = LinkedHashMap<String, ScriptTable>();
    for (var i = 0; i < scriptCount; i++) {
      final scriptOffset = scriptOffsets[i];
      if (scriptOffset == 0) {
        _log.warning(
            'Script offset at index $i is zero, skipping tag ${scriptTags[i]}');
        continue;
      }
      final absoluteOffset = offset + scriptOffset;
      scripts[scriptTags[i]] = _readScriptTable(data, absoluteOffset);
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
      if (i > 0 && langSysTags[i].compareTo(langSysTags[i - 1]) < 0) {
        _log.warning(
            'LangSysRecords not sorted alphabetically: ${langSysTags[i]} < ${langSysTags[i - 1]}');
      }
    }

    LangSysTable? defaultLangSys;
    if (defaultLangSysOffset != 0) {
      defaultLangSys = _readLangSysTable(data, offset + defaultLangSysOffset);
    }

    final langSysTables = LinkedHashMap<String, LangSysTable>();
    for (var i = 0; i < langSysCount; i++) {
      final langSysOffset = langSysOffsets[i];
      if (langSysOffset == 0) {
        _log.warning(
            'LangSys offset is zero for tag ${langSysTags[i]}, skipping');
        continue;
      }
      langSysTables[langSysTags[i]] =
          _readLangSysTable(data, offset + langSysOffset);
    }

    return ScriptTable(defaultLangSys, langSysTables);
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
      if (i > 0 && featureTags[i].compareTo(featureTags[i - 1]) < 0) {
        final currentTag = featureTags[i];
        final previousTag = featureTags[i - 1];
        if (_fourCharWord.hasMatch(currentTag) &&
            _fourCharWord.hasMatch(previousTag)) {
          _log.fine('Feature tags appear unsorted: $currentTag < $previousTag');
        } else {
          _log.warning(
              'Feature tags not sorted: $currentTag < $previousTag, using empty feature list');
          return FeatureListTable(0, const <FeatureRecord>[]);
        }
      }
      featureOffsets[i] = data.readUnsignedShort();
    }

    final records = List<FeatureRecord>.generate(featureCount, (index) {
      final featureOffset = featureOffsets[index];
      final table = _readFeatureTable(data, offset + featureOffset);
      return FeatureRecord(featureTags[index], table);
    });
    return FeatureListTable(featureCount, records);
  }

  FeatureTable _readFeatureTable(TtfDataStream data, int offset) {
    data.seek(offset);
    final featureParams = data.readUnsignedShort();
    final lookupIndexCount = data.readUnsignedShort();
    final lookupListIndices = data.readUnsignedShortArray(lookupIndexCount);
    return FeatureTable(featureParams, lookupIndexCount, lookupListIndices);
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
      if (lookupOffset == 0) {
        _log.warning(
            'Lookup offset is zero at index $index, inserting empty lookup table');
        return LookupTable(0, 0, 0, const <LookupSubTable>[]);
      }
      return _readLookupTable(data, offset + lookupOffset);
    });
    return LookupListTable(lookupCount, lookups);
  }

  LookupTable _readLookupTable(TtfDataStream data, int offset) {
    data.seek(offset);
    var lookupType = data.readUnsignedShort();
    final lookupFlag = data.readUnsignedShort();
    final subTableCount = data.readUnsignedShort();
    final subTableOffsets = List<int>.filled(subTableCount, 0);
    for (var i = 0; i < subTableCount; i++) {
      subTableOffsets[i] = data.readUnsignedShort();
    }
    var markFilteringSet = 0;
    if ((lookupFlag & 0x0010) != 0) {
      markFilteringSet = data.readUnsignedShort();
    }

    final subTables = <LookupSubTable>[];
    if (lookupType == 7) {
      for (var i = 0; i < subTableCount; i++) {
        final extensionBase = offset + subTableOffsets[i];
        data.seek(extensionBase);
        final substFormat = data.readUnsignedShort();
        if (substFormat != 1) {
          _log.warning(
              'Unsupported ExtensionSubstFormat $substFormat at offset $extensionBase');
          continue;
        }
        final extensionLookupType = data.readUnsignedShort();
        final extensionOffset = data.readUnsignedInt();
        final actualOffset = extensionBase + extensionOffset;
        final subTable =
            _readLookupSubtable(data, actualOffset, extensionLookupType);
        if (subTable != null) {
          subTables.add(subTable);
          lookupType = extensionLookupType;
        }
      }
    } else {
      for (var i = 0; i < subTableCount; i++) {
        final relativeOffset = subTableOffsets[i];
        if (relativeOffset == 0) {
          continue;
        }
        final subTable =
            _readLookupSubtable(data, offset + relativeOffset, lookupType);
        if (subTable != null) {
          subTables.add(subTable);
        }
      }
    }
    return LookupTable(lookupType, lookupFlag, markFilteringSet, subTables);
  }

  LookupSubTable? _readLookupSubtable(
      TtfDataStream data, int offset, int lookupType) {
    switch (lookupType) {
      case 1:
        return _readSingleLookupSubTable(data, offset);
      case 2:
        return _readMultipleSubstitutionSubtable(data, offset);
      case 3:
        return _readAlternateSubstitutionSubtable(data, offset);
      case 4:
        return _readLigatureSubstitutionSubtable(data, offset);
      default:
        _log.fine('GSUB lookup type $lookupType not supported yet');
        return null;
    }
  }

  LookupSubTable? _readSingleLookupSubTable(TtfDataStream data, int offset) {
    data.seek(offset);
    final substFormat = data.readUnsignedShort();
    switch (substFormat) {
      case 1:
        {
          final coverageOffset = data.readUnsignedShort();
          final deltaGlyphId = data.readSignedShort();
          final coverageTable =
              _readCoverageTable(data, offset + coverageOffset);
          return LookupTypeSingleSubstFormat1(
              substFormat, coverageTable, deltaGlyphId);
        }
      case 2:
        {
          final coverageOffset = data.readUnsignedShort();
          final glyphCount = data.readUnsignedShort();
          final substituteGlyphIds = data.readUnsignedShortArray(glyphCount);
          final coverageTable =
              _readCoverageTable(data, offset + coverageOffset);
          return LookupTypeSingleSubstFormat2(
              substFormat, coverageTable, substituteGlyphIds);
        }
      default:
        _log.warning(
            'Unknown substFormat $substFormat in single substitution lookup');
        return null;
    }
  }

  LookupSubTable? _readMultipleSubstitutionSubtable(
      TtfDataStream data, int offset) {
    data.seek(offset);
    final substFormat = data.readUnsignedShort();
    if (substFormat != 1) {
      throw IOException(
          'Expected substFormat 1 for multiple substitution, got $substFormat');
    }
    final coverageOffset = data.readUnsignedShort();
    final sequenceCount = data.readUnsignedShort();
    final sequenceOffsets = data.readUnsignedShortArray(sequenceCount);
    final coverageTable = _readCoverageTable(data, offset + coverageOffset);
    if (coverageTable.getSize() != sequenceCount) {
      throw IOException(
          'Coverage count ${coverageTable.getSize()} does not match sequence count $sequenceCount');
    }
    final sequences = <SequenceTable>[];
    for (var i = 0; i < sequenceCount; i++) {
      data.seek(offset + sequenceOffsets[i]);
      final glyphCount = data.readUnsignedShort();
      final substituteGlyphIds = data.readUnsignedShortArray(glyphCount);
      sequences.add(SequenceTable(glyphCount, substituteGlyphIds));
    }
    return LookupTypeMultipleSubstitutionFormat1(
        substFormat, coverageTable, sequences);
  }

  LookupSubTable? _readAlternateSubstitutionSubtable(
      TtfDataStream data, int offset) {
    data.seek(offset);
    final substFormat = data.readUnsignedShort();
    if (substFormat != 1) {
      throw IOException(
          'Expected substFormat 1 for alternate substitution, got $substFormat');
    }
    final coverageOffset = data.readUnsignedShort();
    final altSetCount = data.readUnsignedShort();
    final alternateOffsets = data.readUnsignedShortArray(altSetCount);
    final coverageTable = _readCoverageTable(data, offset + coverageOffset);
    if (coverageTable.getSize() != altSetCount) {
      throw IOException(
          'Coverage count ${coverageTable.getSize()} does not match alternate set count $altSetCount');
    }
    final alternateSets = <AlternateSetTable>[];
    for (var i = 0; i < altSetCount; i++) {
      data.seek(offset + alternateOffsets[i]);
      final glyphCount = data.readUnsignedShort();
      final alternateGlyphIds = data.readUnsignedShortArray(glyphCount);
      alternateSets.add(AlternateSetTable(glyphCount, alternateGlyphIds));
    }
    return LookupTypeAlternateSubstitutionFormat1(
        substFormat, coverageTable, alternateSets);
  }

  LookupSubTable? _readLigatureSubstitutionSubtable(
      TtfDataStream data, int offset) {
    data.seek(offset);
    final substFormat = data.readUnsignedShort();
    if (substFormat != 1) {
      throw IOException(
          'Expected substFormat 1 for ligature substitution, got $substFormat');
    }
    final coverageOffset = data.readUnsignedShort();
    final ligatureCount = data.readUnsignedShort();
    final ligatureOffsets = data.readUnsignedShortArray(ligatureCount);
    final coverageTable = _readCoverageTable(data, offset + coverageOffset);
    if (coverageTable.getSize() != ligatureCount) {
      throw IOException(
          'Coverage count ${coverageTable.getSize()} does not match ligature count $ligatureCount');
    }
    final ligatureSets = <LigatureSetTable>[];
    for (var i = 0; i < ligatureCount; i++) {
      final coverageGlyphId = coverageTable.getGlyphId(i);
      ligatureSets.add(_readLigatureSetTable(
          data, offset + ligatureOffsets[i], coverageGlyphId));
    }
    return LookupTypeLigatureSubstitutionSubstFormat1(
        substFormat, coverageTable, ligatureSets);
  }

  LigatureSetTable _readLigatureSetTable(
      TtfDataStream data, int offset, int coverageGlyphId) {
    data.seek(offset);
    final ligatureCount = data.readUnsignedShort();
    final ligatureOffsets = data.readUnsignedShortArray(ligatureCount);
    final ligatures = <LigatureTable>[];
    for (var i = 0; i < ligatureCount; i++) {
      ligatures.add(_readLigatureTable(
          data, offset + ligatureOffsets[i], coverageGlyphId));
    }
    return LigatureSetTable(ligatureCount, ligatures);
  }

  LigatureTable _readLigatureTable(
      TtfDataStream data, int offset, int coverageGlyphId) {
    data.seek(offset);
    final ligatureGlyph = data.readUnsignedShort();
    final componentCount = data.readUnsignedShort();
    if (componentCount <= 0 || componentCount > 100) {
      throw IOException(
          'Ligature table componentCount $componentCount is implausible');
    }
    final componentGlyphIds = List<int>.filled(componentCount, 0);
    componentGlyphIds[0] = coverageGlyphId;
    for (var i = 1; i < componentCount; i++) {
      componentGlyphIds[i] = data.readUnsignedShort();
    }
    return LigatureTable(ligatureGlyph, componentCount, componentGlyphIds);
  }

  CoverageTable _readCoverageTable(TtfDataStream data, int offset) {
    data.seek(offset);
    final coverageFormat = data.readUnsignedShort();
    switch (coverageFormat) {
      case 1:
        {
          final glyphCount = data.readUnsignedShort();
          final glyphArray = data.readUnsignedShortArray(glyphCount);
          return CoverageTableFormat1(coverageFormat, glyphArray);
        }
      case 2:
        {
          final rangeCount = data.readUnsignedShort();
          final ranges = <RangeRecord>[];
          for (var i = 0; i < rangeCount; i++) {
            ranges.add(_readRangeRecord(data));
          }
          return CoverageTableFormat2(coverageFormat, ranges);
        }
      default:
        throw IOException('Unsupported coverage format $coverageFormat');
    }
  }

  RangeRecord _readRangeRecord(TtfDataStream data) {
    final startGlyphId = data.readUnsignedShort();
    final endGlyphId = data.readUnsignedShort();
    final startCoverageIndex = data.readUnsignedShort();
    return RangeRecord(startGlyphId, endGlyphId, startCoverageIndex);
  }

  String _selectScriptTag(List<String> tags) {
    if (tags.isEmpty) {
      return OpenTypeScript.tagDefault;
    }
    if (tags.length == 1) {
      final tag = tags.first;
      if (tag == OpenTypeScript.inherited ||
          (tag == OpenTypeScript.tagDefault && !_scriptList.containsKey(tag))) {
        _lastUsedSupportedScript ??=
            _scriptList.isNotEmpty ? _scriptList.keys.first : tag;
        return _lastUsedSupportedScript!;
      }
    }
    for (final tag in tags) {
      if (_scriptList.containsKey(tag)) {
        _lastUsedSupportedScript = tag;
        return tag;
      }
    }
    return tags.first;
  }

  Iterable<LangSysTable> _getLangSysTables(String scriptTag) {
    final scriptTable = _scriptList[scriptTag];
    if (scriptTable == null) {
      return const <LangSysTable>[];
    }
    if (scriptTable.defaultLangSysTable == null) {
      return scriptTable.langSysTables.values;
    }
    final list = <LangSysTable>[];
    list.addAll(scriptTable.langSysTables.values);
    list.add(scriptTable.defaultLangSysTable!);
    return list;
  }

  List<FeatureRecord> _getFeatureRecords(
    Iterable<LangSysTable> langSysTables,
    List<String>? enabledFeatures,
  ) {
    final featureList = _featureListTable;
    if (featureList == null || langSysTables.isEmpty) {
      return const <FeatureRecord>[];
    }
    final result = <FeatureRecord>[];
    final featureRecords = featureList.featureRecords;
    for (final langSysTable in langSysTables) {
      final required = langSysTable.requiredFeatureIndex;
      if (required != 0xffff && required < featureRecords.length) {
        result.add(featureRecords[required]);
      }
      for (final index in langSysTable.featureIndices) {
        if (index < featureRecords.length) {
          final record = featureRecords[index];
          if (enabledFeatures == null ||
              enabledFeatures.contains(record.featureTag)) {
            result.add(record);
          }
        }
      }
    }

    if (_containsFeature(result, 'vrt2')) {
      _removeFeature(result, 'vert');
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

  bool _containsFeature(List<FeatureRecord> records, String featureTag) =>
      records.any((record) => record.featureTag == featureTag);

  void _removeFeature(List<FeatureRecord> records, String featureTag) {
    records.removeWhere((record) => record.featureTag == featureTag);
  }

  int _applyFeature(FeatureRecord featureRecord, int gid) {
    final lookupList = _lookupListTable;
    if (lookupList == null) {
      return gid;
    }
    var lookupResult = gid;
    final lookups = lookupList.lookups;
    for (final lookupIndex in featureRecord.featureTable.lookupListIndices) {
      if (lookupIndex < 0 || lookupIndex >= lookups.length) {
        _log.warning(
            'Skipping GSUB feature ${featureRecord.featureTag} with invalid lookupListIndex $lookupIndex');
        continue;
      }
      final lookupTable = lookups[lookupIndex];
      if (lookupTable.lookupType != 1) {
        _log.fine(
            'Lookup type ${lookupTable.lookupType} not supported for feature ${featureRecord.featureTag}');
        continue;
      }
      lookupResult = _doLookup(lookupTable, lookupResult);
    }
    return lookupResult;
  }

  int _doLookup(LookupTable lookupTable, int gid) {
    for (final subTable in lookupTable.subTables) {
      final coverageIndex = subTable.coverageTable.getCoverageIndex(gid);
      if (coverageIndex >= 0) {
        return subTable.doSubstitution(gid, coverageIndex);
      }
    }
    return gid;
  }

  /// Apply glyph substitutions for [gid] according to [scriptTags] and [enabledFeatures].
  int getSubstitution(
      int gid, List<String> scriptTags, List<String> enabledFeatures) {
    if (gid == -1) {
      return -1;
    }
    final cached = _lookupCache[gid];
    if (cached != null) {
      return cached;
    }
    final scriptTag = _selectScriptTag(scriptTags);
    final langSysTables = _getLangSysTables(scriptTag);
    final featureRecords = _getFeatureRecords(langSysTables, enabledFeatures);
    var substituted = gid;
    for (final featureRecord in featureRecords) {
      substituted = _applyFeature(featureRecord, substituted);
    }
    _lookupCache[gid] = substituted;
    _reverseLookup[substituted] = gid;
    return substituted;
  }

  /// Retrieve the original glyph id for a substituted glyph.
  int getUnsubstitution(int substituted) {
    final original = _reverseLookup[substituted];
    if (original == null) {
      _log.warning(
          'Glyph $substituted was not previously substituted, returning original value');
      return substituted;
    }
    return original;
  }

  /// Returns cached GSUB data for the first supported script.
  GsubData getGsubData() => _gsubData ?? GsubData.noDataFound;

  /// Extracts GSUB data for the supplied [scriptTag] without caching.
  GsubData? getGsubDataForScript(String scriptTag) {
    final scriptTable = _scriptList[scriptTag];
    if (scriptTable == null ||
        _featureListTable == null ||
        _lookupListTable == null) {
      return null;
    }
    return GlyphSubstitutionDataExtractor().getGsubDataForScript(
      scriptTag,
      scriptTable,
      _featureListTable!,
      _lookupListTable!,
    );
  }

  /// Supported OpenType script tags exposed by this GSUB table.
  Set<String> getSupportedScriptTags() =>
      UnmodifiableSetView<String>(_scriptList.keys.toSet());
}
