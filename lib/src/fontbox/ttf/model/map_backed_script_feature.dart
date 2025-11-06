import 'package:collection/collection.dart';

import 'script_feature.dart';

class MapBackedScriptFeature implements ScriptFeature {
  MapBackedScriptFeature(String name, Map<List<int>, List<int>> featureMap)
      : name = name,
        _featureMap = <_GlyphSequenceKey, List<int>>{} {
    featureMap.forEach((key, value) {
      final normalizedKey = List<int>.unmodifiable(key);
      final normalizedValue = List<int>.unmodifiable(value);
      _featureMap[_GlyphSequenceKey(normalizedKey)] = normalizedValue;
    });
  }

  @override
  final String name;

  final Map<_GlyphSequenceKey, List<int>> _featureMap;

  @override
  Set<List<int>> getAllGlyphIdsForSubstitution() {
    final keys = _featureMap.keys.map((k) => k.sequence).toSet();
    return Set<List<int>>.unmodifiable(keys);
  }

  @override
  bool canReplaceGlyphs(List<int> glyphIds) =>
      _featureMap.containsKey(_GlyphSequenceKey(List<int>.unmodifiable(glyphIds)));

  @override
  List<int> getReplacementForGlyphs(List<int> glyphIds) {
    final key = _GlyphSequenceKey(List<int>.unmodifiable(glyphIds));
    final replacement = _featureMap[key];
    if (replacement == null) {
      throw UnsupportedError('Glyph sequence $glyphIds cannot be replaced');
    }
    return replacement;
  }

  @override
  int get hashCode => Object.hash(
        name,
        const DeepCollectionEquality().hash(
          _featureMap.map((key, value) => MapEntry(key.sequence, value)),
        ),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! MapBackedScriptFeature) {
      return false;
    }
    return name == other.name &&
        const DeepCollectionEquality().equals(
          _featureMap.map((key, value) => MapEntry(key.sequence, value)),
          other._featureMap.map((key, value) => MapEntry(key.sequence, value)),
        );
  }
}

class _GlyphSequenceKey {
  _GlyphSequenceKey(this.sequence);

  final List<int> sequence;

  @override
  int get hashCode => const ListEquality<int>().hash(sequence);

  @override
  bool operator ==(Object other) =>
      other is _GlyphSequenceKey && const ListEquality<int>().equals(sequence, other.sequence);
}
