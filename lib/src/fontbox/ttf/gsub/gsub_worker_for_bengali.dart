import 'package:logging/logging.dart';

import '../cmap_lookup.dart';
import '../model/gsub_data.dart';
import '../model/script_feature.dart';
import 'glyph_array_splitter_regex_impl.dart';
import 'gsub_worker.dart';

/// Bengali-specific GSUB worker.
class GsubWorkerForBengali implements GsubWorker {
  GsubWorkerForBengali(this._cmapLookup, this._gsubData)
      : _beforeHalfGlyphIds =
            _computeBeforeHalfGlyphIds(_cmapLookup, _gsubData),
        _beforeAndAfterSpanGlyphIds =
            _computeBeforeAndAfterSpanGlyphIds(_cmapLookup);

  static final Logger _log = Logger('fontbox.GsubWorkerForBengali');

  static const String _initFeature = 'init';
  static const List<String> _featuresInOrder = <String>[
    'locl',
    'nukt',
    'akhn',
    'rphf',
    'blwf',
    'pstf',
    'half',
    'vatu',
    'cjct',
    _initFeature,
    'pres',
    'abvs',
    'blws',
    'psts',
    'haln',
    'calt',
  ];

  static const List<int> _beforeHalfChars = <int>[0x09BF, 0x09C7, 0x09C8];
  static const List<_BeforeAndAfterSpanComponent> _beforeAndAfterSpanChars =
      <_BeforeAndAfterSpanComponent>[
    _BeforeAndAfterSpanComponent(0x09CB, 0x09C7, 0x09BE),
    _BeforeAndAfterSpanComponent(0x09CC, 0x09C7, 0x09D7),
  ];

  final CMapLookup _cmapLookup;
  final GsubData _gsubData;
  final List<int> _beforeHalfGlyphIds;
  final Map<int, _BeforeAndAfterSpanComponent> _beforeAndAfterSpanGlyphIds;

  @override
  List<int> applyTransforms(List<int> originalGlyphIds) {
    var glyphs = originalGlyphIds;

    for (final feature in _featuresInOrder) {
      if (!_gsubData.isFeatureSupported(feature)) {
        _log.fine('The feature $feature was not found');
        continue;
      }

      _log.fine('Applying the feature $feature');
      glyphs = _applyGsubFeature(_gsubData.getFeature(feature), glyphs);
    }

    return List<int>.unmodifiable(_repositionGlyphs(glyphs));
  }

  List<int> _repositionGlyphs(List<int> originalGlyphIds) {
    final glyphsRepositionedByBeforeHalf =
        _repositionBeforeHalfGlyphIds(originalGlyphIds);
    return _repositionBeforeAndAfterSpanGlyphIds(
        glyphsRepositionedByBeforeHalf);
  }

  List<int> _repositionBeforeHalfGlyphIds(List<int> originalGlyphIds) {
    final repositioned = List<int>.from(originalGlyphIds);
    for (var index = 1; index < originalGlyphIds.length; index++) {
      final glyphId = originalGlyphIds[index];
      if (_beforeHalfGlyphIds.contains(glyphId)) {
        final previousGlyphId = originalGlyphIds[index - 1];
        repositioned[index] = previousGlyphId;
        repositioned[index - 1] = glyphId;
      }
    }
    return repositioned;
  }

  List<int> _repositionBeforeAndAfterSpanGlyphIds(List<int> originalGlyphIds) {
    final repositioned = List<int>.from(originalGlyphIds);

    for (var index = 1; index < originalGlyphIds.length; index++) {
      final glyphId = originalGlyphIds[index];
      final component = _beforeAndAfterSpanGlyphIds[glyphId];
      if (component != null) {
        final previousGlyphId = originalGlyphIds[index - 1];
        repositioned[index] = previousGlyphId;
        repositioned[index - 1] = _glyphId(component.beforeComponentCharacter);
        repositioned.insert(
            index + 1, _glyphId(component.afterComponentCharacter));
      }
    }

    return repositioned;
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
        final replacement = scriptFeature.getReplacementForGlyphs(chunk);
        processedGlyphs.addAll(replacement);
      } else {
        processedGlyphs.addAll(chunk);
      }
    }

    _log.fine(
        'originalGlyphs: $originalGlyphs, gsubProcessedGlyphs: $processedGlyphs');
    return processedGlyphs;
  }

  static List<int> _computeBeforeHalfGlyphIds(
      CMapLookup cmapLookup, GsubData gsubData) {
    final glyphIds = <int>[];
    for (final charCode in _beforeHalfChars) {
      glyphIds.add(_glyphIdFromLookup(cmapLookup, charCode));
    }

    if (gsubData.isFeatureSupported(_initFeature)) {
      final feature = gsubData.getFeature(_initFeature);
      for (final glyphCluster in feature.getAllGlyphIdsForSubstitution()) {
        glyphIds.addAll(feature.getReplacementForGlyphs(glyphCluster));
      }
    }

    return List<int>.unmodifiable(glyphIds);
  }

  static Map<int, _BeforeAndAfterSpanComponent>
      _computeBeforeAndAfterSpanGlyphIds(
    CMapLookup cmapLookup,
  ) {
    final result = <int, _BeforeAndAfterSpanComponent>{};
    for (final component in _beforeAndAfterSpanChars) {
      result[_glyphIdFromLookup(cmapLookup, component.originalCharacter)] =
          component;
    }
    return Map<int, _BeforeAndAfterSpanComponent>.unmodifiable(result);
  }

  static int _glyphIdFromLookup(CMapLookup cmapLookup, int codePoint) =>
      cmapLookup.getGlyphId(codePoint);

  int _glyphId(int codePoint) => _glyphIdFromLookup(_cmapLookup, codePoint);
}

class _BeforeAndAfterSpanComponent {
  const _BeforeAndAfterSpanComponent(this.originalCharacter,
      this.beforeComponentCharacter, this.afterComponentCharacter);

  final int originalCharacter;
  final int beforeComponentCharacter;
  final int afterComponentCharacter;
}
