import 'gsub_data.dart';
import 'language.dart';
import 'map_backed_script_feature.dart';
import 'script_feature.dart';

class MapBackedGsubData implements GsubData {
  MapBackedGsubData(
    this.language,
    this.activeScriptName,
    Map<String, Map<List<int>, List<int>>> glyphSubstitutionMap,
  ) : _features = <String, MapBackedScriptFeature>{} {
    glyphSubstitutionMap.forEach((featureName, substitutions) {
      _features[featureName] = MapBackedScriptFeature(featureName, substitutions);
    });
  }

  @override
  final Language language;

  @override
  final String activeScriptName;

  final Map<String, MapBackedScriptFeature> _features;

  @override
  bool isFeatureSupported(String featureName) => _features.containsKey(featureName);

  @override
  ScriptFeature getFeature(String featureName) {
    final feature = _features[featureName];
    if (feature == null) {
      throw UnsupportedError('Feature $featureName is not supported');
    }
    return feature;
  }

  @override
  Set<String> getSupportedFeatures() => Set<String>.unmodifiable(_features.keys);
}
