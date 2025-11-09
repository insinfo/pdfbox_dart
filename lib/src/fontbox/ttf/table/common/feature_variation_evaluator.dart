import 'feature_variations.dart';

/// Evaluates FeatureVariation condition sets against normalized axis coordinates.
class FeatureVariationEvaluator {
  const FeatureVariationEvaluator(this.axisCoordinates);

  /// Normalised F2.14 coordinates mapped by axis index.
  final List<double> axisCoordinates;

  bool matches(FeatureVariationRecord record) {
    if (record.conditions.isEmpty) {
      return true;
    }
    for (final condition in record.conditions) {
      final axisIndex = condition.axisIndex;
      final axisValue =
          axisIndex < axisCoordinates.length ? axisCoordinates[axisIndex] : 0.0;
      if (axisValue < condition.minValue || axisValue > condition.maxValue) {
        return false;
      }
    }
    return true;
  }
}
