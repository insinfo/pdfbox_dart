import 'package:logging/logging.dart';

import '../cmap_lookup.dart';
import '../model/gsub_data.dart';
import '../model/script_feature.dart';
import 'glyph_array_splitter_regex_impl.dart';
import 'gsub_worker.dart';

/// Gujarati-specific GSUB worker.
class GsubWorkerForGujarati implements GsubWorker {
  GsubWorkerForGujarati(CMapLookup cmapLookup, this._gsubData)
      : _beforeHalfGlyphIds = _getBeforeHalfGlyphIds(cmapLookup),
        _rephGlyphIds = _getRephGlyphIds(cmapLookup),
        _beforeRephGlyphIds = _getBeforeRephGlyphIds(cmapLookup);

  static final Logger _log = Logger('fontbox.GsubWorkerForGujarati');

  static const String _rkrfFeature = 'rkrf';
  static const String _vatuFeature = 'vatu';

  static const List<String> _featuresInOrder = <String>[
    'locl',
    'nukt',
    'akhn',
    'rphf',
    _rkrfFeature,
    'blwf',
    'half',
    _vatuFeature,
    'cjct',
    'pres',
    'abvs',
    'blws',
    'psts',
    'haln',
    'calt',
  ];

  static const List<int> _rephChars = <int>[0x0AB0, 0x0ACD];
  static const List<int> _beforeRephChars = <int>[0x0ABE, 0x0AC0];
  static const int _beforeHalfChar = 0x0ABF;

  final GsubData _gsubData;
  final List<int> _beforeHalfGlyphIds;
  final List<int> _rephGlyphIds;
  final List<int> _beforeRephGlyphIds;

  @override
  List<int> applyTransforms(List<int> originalGlyphIds) {
    var glyphs = _adjustRephPosition(originalGlyphIds);
    glyphs = _repositionGlyphs(glyphs);

    for (final feature in _featuresInOrder) {
      if (!_gsubData.isFeatureSupported(feature)) {
        if (feature == _rkrfFeature &&
            _gsubData.isFeatureSupported(_vatuFeature)) {
          glyphs =
              _applyRkrfFeature(_gsubData.getFeature(_vatuFeature), glyphs);
        }
        _log.fine('The feature $feature was not found');
        continue;
      }

      _log.fine('Applying the feature $feature');
      glyphs = _applyGsubFeature(_gsubData.getFeature(feature), glyphs);
    }

    return List<int>.unmodifiable(glyphs);
  }

  List<int> _applyRkrfFeature(
      ScriptFeature feature, List<int> originalGlyphIds) {
    final rkrfGlyphIds = feature.getAllGlyphIdsForSubstitution();
    if (rkrfGlyphIds.isEmpty) {
      _log.fine('Glyph substitution list for ${feature.name} is empty.');
      return originalGlyphIds;
    }

    var rkrfReplacement = 0;
    for (final glyphList in rkrfGlyphIds) {
      if (glyphList.length > 1) {
        rkrfReplacement = glyphList[1];
        break;
      }
    }

    if (rkrfReplacement == 0) {
      _log.fine(
          'Cannot find rkrf candidate. The glyph list has no replacement.');
      return originalGlyphIds;
    }

    final result = List<int>.from(originalGlyphIds);
    for (var index = originalGlyphIds.length - 1; index > 1; index--) {
      final raGlyph = originalGlyphIds[index];
      if (raGlyph == _rephGlyphIds[0]) {
        final viramaGlyph = originalGlyphIds[index - 1];
        if (viramaGlyph == _rephGlyphIds[1]) {
          result[index - 1] = rkrfReplacement;
          result.removeAt(index);
        }
      }
    }
    return result;
  }

  List<int> _repositionGlyphs(List<int> originalGlyphIds) {
    final repositioned = List<int>.from(originalGlyphIds);
    final listSize = repositioned.length;
    var foundIndex = listSize - 1;
    var nextIndex = listSize - 2;
    while (nextIndex > -1) {
      final glyph = repositioned[foundIndex];
      final prevIndex = foundIndex + 1;
      if (_beforeHalfGlyphIds.contains(glyph)) {
        final movedGlyph = repositioned.removeAt(foundIndex);
        repositioned.insert(nextIndex--, movedGlyph);
      } else if (_rephGlyphIds[1] == glyph && prevIndex < listSize) {
        final prevGlyph = repositioned[prevIndex];
        if (_beforeHalfGlyphIds.contains(prevGlyph)) {
          final movedGlyph = repositioned.removeAt(prevIndex);
          repositioned.insert(nextIndex--, movedGlyph);
        }
      }
      foundIndex = nextIndex--;
    }
    return repositioned;
  }

  List<int> _adjustRephPosition(List<int> originalGlyphIds) {
    final adjusted = List<int>.from(originalGlyphIds);
    for (var index = 0; index < originalGlyphIds.length - 2; index++) {
      final raGlyph = originalGlyphIds[index];
      final viramaGlyph = originalGlyphIds[index + 1];
      if (raGlyph == _rephGlyphIds[0] && viramaGlyph == _rephGlyphIds[1]) {
        final nextConsonantGlyph = originalGlyphIds[index + 2];
        adjusted[index] = nextConsonantGlyph;
        adjusted[index + 1] = raGlyph;
        adjusted[index + 2] = viramaGlyph;

        if (index + 3 < originalGlyphIds.length) {
          final matraGlyph = originalGlyphIds[index + 3];
          if (_beforeRephGlyphIds.contains(matraGlyph)) {
            adjusted[index + 1] = matraGlyph;
            adjusted[index + 2] = raGlyph;
            adjusted[index + 3] = viramaGlyph;
          }
        }
      }
    }
    return adjusted;
  }

  List<int> _applyGsubFeature(
      ScriptFeature scriptFeature, List<int> originalGlyphs) {
    final glyphIdsForSubstitution =
        scriptFeature.getAllGlyphIdsForSubstitution();
    if (glyphIdsForSubstitution.isEmpty) {
      _log.fine(
          'getAllGlyphIdsForSubstitution() for ${scriptFeature.name} is empty');
      return originalGlyphs;
    }

    final splitter = GlyphArraySplitterRegexImpl(glyphIdsForSubstitution);
    final tokens = splitter.split(originalGlyphs);
    final processedGlyphs = <int>[];
    for (final chunk in tokens) {
      if (scriptFeature.canReplaceGlyphs(chunk)) {
        processedGlyphs.addAll(scriptFeature.getReplacementForGlyphs(chunk));
      } else {
        processedGlyphs.addAll(chunk);
      }
    }
    _log.fine(
        'originalGlyphs: $originalGlyphs, gsubProcessedGlyphs: $processedGlyphs');
    return processedGlyphs;
  }

  static List<int> _getBeforeHalfGlyphIds(CMapLookup cmapLookup) =>
      List<int>.unmodifiable(<int>[cmapLookup.getGlyphId(_beforeHalfChar)]);

  static List<int> _getRephGlyphIds(CMapLookup cmapLookup) {
    final result = <int>[];
    for (final charCode in _rephChars) {
      result.add(cmapLookup.getGlyphId(charCode));
    }
    return List<int>.unmodifiable(result);
  }

  static List<int> _getBeforeRephGlyphIds(CMapLookup cmapLookup) {
    final glyphIds = <int>[];
    for (final charCode in _beforeRephChars) {
      glyphIds.add(cmapLookup.getGlyphId(charCode));
    }
    return List<int>.unmodifiable(glyphIds);
  }
}
