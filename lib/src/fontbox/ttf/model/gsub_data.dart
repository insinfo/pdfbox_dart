import 'language.dart';
import 'script_feature.dart';

/// Contract that exposes GSUB feature data for glyph substitution workflows.
abstract class GsubData {
  static final GsubData noDataFound = _NoDataFoundGsubData();

  Language get language;

  String get activeScriptName;

  bool isFeatureSupported(String featureName);

  ScriptFeature getFeature(String featureName);

  Set<String> getSupportedFeatures();
}

class _NoDataFoundGsubData implements GsubData {
  T _error<T>() => throw UnsupportedError('No GSUB data available');

  @override
  Language get language => _error();

  @override
  String get activeScriptName => _error();

  @override
  bool isFeatureSupported(String featureName) => _error();

  @override
  ScriptFeature getFeature(String featureName) => _error();

  @override
  Set<String> getSupportedFeatures() => _error();
}
