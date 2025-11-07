import 'package:logging/logging.dart';

import '../cmap_lookup.dart';
import '../model/gsub_data.dart';
import '../model/script_feature.dart';
import 'glyph_array_splitter_regex_impl.dart';
import 'gsub_worker.dart';

/// Latin-specific implementation of the GSUB workflow.
class GsubWorkerForLatin implements GsubWorker {
  GsubWorkerForLatin(this._cmapLookup, this._gsubData);

  static final Logger _log = Logger('fontbox.GsubWorkerForLatin');
  static const List<String> _featuresInOrder = <String>['ccmp', 'liga', 'clig'];

  // ignore: unused_field
  final CMapLookup _cmapLookup;
  final GsubData _gsubData;

  @override
  List<int> applyTransforms(List<int> originalGlyphIds) {
    var glyphs = originalGlyphIds;

    for (final feature in _featuresInOrder) {
      if (!_gsubData.isFeatureSupported(feature)) {
        _log.fine('The feature $feature was not found');
        continue;
      }

      _log.fine('Applying the feature $feature');
      final scriptFeature = _gsubData.getFeature(feature);
      glyphs = _applyGsubFeature(scriptFeature, glyphs);
    }

    return List<int>.unmodifiable(glyphs);
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
}
