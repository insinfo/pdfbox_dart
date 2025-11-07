import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import '../model/gsub_data.dart';
import '../model/language.dart';
import '../model/map_backed_gsub_data.dart';
import '../table/common/feature_list_table.dart';
import '../table/common/feature_record.dart';
import '../table/common/lang_sys_table.dart';
import '../table/common/lookup_list_table.dart';
import '../table/common/lookup_table.dart';
import '../table/common/script_table.dart';
import '../table/gsub/lookup_type_alternate_substitution_format1.dart';
import '../table/gsub/lookup_type_ligature_substitution_subst_format1.dart';
import '../table/gsub/lookup_type_multiple_substitution_format1.dart';
import '../table/gsub/lookup_type_single_subst_format1.dart';
import '../table/gsub/lookup_type_single_subst_format2.dart';

class GlyphSubstitutionDataExtractor {
  GlyphSubstitutionDataExtractor();

  static final Logger _log = Logger('fontbox.GlyphSubstitutionDataExtractor');
  static const ListEquality<int> _listEquality = ListEquality<int>();

  GsubData getGsubData(
    Map<String, ScriptTable> scriptList,
    FeatureListTable featureListTable,
    LookupListTable lookupListTable,
  ) {
    final details = _getSupportedLanguage(scriptList);
    if (details == null) {
      return GsubData.noDataFound;
    }
    return _buildGsubData(featureListTable, lookupListTable, details);
  }

  GsubData getGsubDataForScript(
    String scriptName,
    ScriptTable scriptTable,
    FeatureListTable featureListTable,
    LookupListTable lookupListTable,
  ) {
    final details =
        _ScriptTableDetails(Language.unspecified, scriptName, scriptTable);
    return _buildGsubData(featureListTable, lookupListTable, details);
  }

  MapBackedGsubData _buildGsubData(
    FeatureListTable featureListTable,
    LookupListTable lookupListTable,
    _ScriptTableDetails details,
  ) {
    final scriptTable = details.scriptTable;
    final Map<String, Map<List<int>, List<int>>> gsubData =
        <String, Map<List<int>, List<int>>>{};

    final defaultLangSys = scriptTable.defaultLangSysTable;
    if (defaultLangSys != null) {
      _populateFromLangSys(
          gsubData, defaultLangSys, featureListTable, lookupListTable);
    }
    for (final langSys in scriptTable.langSysTables.values) {
      _populateFromLangSys(
          gsubData, langSys, featureListTable, lookupListTable);
    }

    return MapBackedGsubData(details.language, details.featureName, gsubData);
  }

  _ScriptTableDetails? _getSupportedLanguage(
      Map<String, ScriptTable> scriptList) {
    for (final language in Language.values) {
      for (final scriptName in language.scriptNames) {
        final table = scriptList[scriptName];
        if (table != null) {
          _log.fine('Language decided: $language $scriptName');
          return _ScriptTableDetails(language, scriptName, table);
        }
      }
    }
    return null;
  }

  void _populateFromLangSys(
    Map<String, Map<List<int>, List<int>>> gsubData,
    LangSysTable langSysTable,
    FeatureListTable featureListTable,
    LookupListTable lookupListTable,
  ) {
    final records = featureListTable.featureRecords;
    for (final index in langSysTable.featureIndices) {
      if (index < records.length) {
        _populateFromFeature(gsubData, records[index], lookupListTable);
      }
    }
  }

  void _populateFromFeature(
    Map<String, Map<List<int>, List<int>>> gsubData,
    FeatureRecord featureRecord,
    LookupListTable lookupListTable,
  ) {
    final lookups = lookupListTable.lookups;
    final glyphSubstitutionMap = LinkedHashMap<List<int>, List<int>>(
      equals: _listEquality.equals,
      hashCode: _listEquality.hash,
      isValidKey: (Object? key) => key is List<int>,
    );

    for (final lookupIndex in featureRecord.featureTable.lookupListIndices) {
      if (lookupIndex < lookups.length) {
        _extractFromLookup(glyphSubstitutionMap, lookups[lookupIndex]);
      }
    }

    _log.fine(
        'Extracted GSUB feature ${featureRecord.featureTag}: $glyphSubstitutionMap');
    gsubData[featureRecord.featureTag] = Map.unmodifiable(glyphSubstitutionMap);
  }

  void _extractFromLookup(
    Map<List<int>, List<int>> glyphSubstitutionMap,
    LookupTable lookupTable,
  ) {
    for (final subTable in lookupTable.subTables) {
      if (subTable is LookupTypeLigatureSubstitutionSubstFormat1) {
        _extractLigature(glyphSubstitutionMap, subTable);
      } else if (subTable is LookupTypeAlternateSubstitutionFormat1) {
        _extractAlternate(glyphSubstitutionMap, subTable);
      } else if (subTable is LookupTypeSingleSubstFormat1) {
        _extractSingleFormat1(glyphSubstitutionMap, subTable);
      } else if (subTable is LookupTypeSingleSubstFormat2) {
        _extractSingleFormat2(glyphSubstitutionMap, subTable);
      } else if (subTable is LookupTypeMultipleSubstitutionFormat1) {
        _extractMultiple(glyphSubstitutionMap, subTable);
      } else {
        _log.fine(
            'Unsupported GSUB lookup type ${subTable.runtimeType}, ignoring');
      }
    }
  }

  void _extractSingleFormat1(
    Map<List<int>, List<int>> glyphSubstitutionMap,
    LookupTypeSingleSubstFormat1 subTable,
  ) {
    final coverage = subTable.coverageTable;
    for (var i = 0; i < coverage.getSize(); i++) {
      final coverageGlyphId = coverage.getGlyphId(i);
      final substituteGlyphId = coverageGlyphId + subTable.deltaGlyphId;
      _putSubstitution(
        glyphSubstitutionMap,
        <int>[substituteGlyphId],
        <int>[coverageGlyphId],
      );
    }
  }

  void _extractSingleFormat2(
    Map<List<int>, List<int>> glyphSubstitutionMap,
    LookupTypeSingleSubstFormat2 subTable,
  ) {
    final coverage = subTable.coverageTable;
    if (coverage.getSize() != subTable.substituteGlyphIds.length) {
      _log.warning(
        'Coverage size ${coverage.getSize()} does not match substitute glyph array ${subTable.substituteGlyphIds.length}',
      );
      return;
    }
    for (var i = 0; i < coverage.getSize(); i++) {
      final coverageGlyphId = coverage.getGlyphId(i);
      final substituteGlyphId = subTable.substituteGlyphIds[i];
      _putSubstitution(
        glyphSubstitutionMap,
        <int>[substituteGlyphId],
        <int>[coverageGlyphId],
      );
    }
  }

  void _extractMultiple(
    Map<List<int>, List<int>> glyphSubstitutionMap,
    LookupTypeMultipleSubstitutionFormat1 subTable,
  ) {
    final coverage = subTable.coverageTable;
    if (coverage.getSize() != subTable.sequenceTables.length) {
      _log.warning(
        'Coverage size ${coverage.getSize()} does not match sequence table count ${subTable.sequenceTables.length}',
      );
      return;
    }
    for (var i = 0; i < coverage.getSize(); i++) {
      final coverageGlyphId = coverage.getGlyphId(i);
      final sequence = subTable.sequenceTables[i];
      _putSubstitution(
        glyphSubstitutionMap,
        List<int>.from(sequence.substituteGlyphIds),
        <int>[coverageGlyphId],
      );
    }
  }

  void _extractAlternate(
    Map<List<int>, List<int>> glyphSubstitutionMap,
    LookupTypeAlternateSubstitutionFormat1 subTable,
  ) {
    final coverage = subTable.coverageTable;
    if (coverage.getSize() != subTable.alternateSetTables.length) {
      _log.warning(
        'Coverage size ${coverage.getSize()} does not match alternate set table count ${subTable.alternateSetTables.length}',
      );
      return;
    }
    for (var i = 0; i < coverage.getSize(); i++) {
      final coverageGlyphId = coverage.getGlyphId(i);
      final alternateSet = subTable.alternateSetTables[i];
      for (final alternateGlyphId in alternateSet.alternateGlyphIds) {
        if (alternateGlyphId != coverageGlyphId) {
          _putSubstitution(
            glyphSubstitutionMap,
            <int>[alternateGlyphId],
            <int>[coverageGlyphId],
          );
          break;
        }
      }
    }
  }

  void _extractLigature(
    Map<List<int>, List<int>> glyphSubstitutionMap,
    LookupTypeLigatureSubstitutionSubstFormat1 subTable,
  ) {
    for (final ligatureSet in subTable.ligatureSetTables) {
      for (final ligature in ligatureSet.ligatureTables) {
        final glyphsToReplace = List<int>.from(ligature.componentGlyphIds);
        _putSubstitution(
          glyphSubstitutionMap,
          <int>[ligature.ligatureGlyph],
          glyphsToReplace,
        );
      }
    }
  }

  void _putSubstitution(
    Map<List<int>, List<int>> glyphSubstitutionMap,
    List<int> newGlyphs,
    List<int> glyphsToBeSubstituted,
  ) {
    final previous = glyphSubstitutionMap[glyphsToBeSubstituted];
    glyphSubstitutionMap[glyphsToBeSubstituted] = newGlyphs;
    if (previous != null) {
      _log.fine(
        'Overriding existing GSUB mapping $glyphsToBeSubstituted : $previous with $newGlyphs',
      );
    }
  }
}

class _ScriptTableDetails {
  _ScriptTableDetails(this.language, this.featureName, this.scriptTable);

  final Language language;
  final String featureName;
  final ScriptTable scriptTable;
}
