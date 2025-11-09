import 'package:pdfbox_dart/src/fontbox/ttf/table/common/feature_variation_evaluator.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/table/common/feature_variations.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureVariationEvaluator', () {
    test('accepts records without conditions', () {
      const record =
          FeatureVariationRecord(const <FeatureVariationCondition>[], 0);
      const evaluator = FeatureVariationEvaluator(<double>[]);

      expect(evaluator.matches(record), isTrue);
    });

    test('resolves axis indices against provided coordinates', () {
      const conditions = <FeatureVariationCondition>[
        FeatureVariationCondition(0, -1.0, 0.5),
        FeatureVariationCondition(1, -0.25, 0.25),
      ];
      const record = FeatureVariationRecord(conditions, 0);
      const evaluator = FeatureVariationEvaluator(<double>[0.4, 0.1]);

      expect(evaluator.matches(record), isTrue);
    });

    test('falls back to zero for missing axis slots', () {
      const conditions = <FeatureVariationCondition>[
        FeatureVariationCondition(0, -0.1, 0.1),
        FeatureVariationCondition(2, -0.2, 0.2),
      ];
      const record = FeatureVariationRecord(conditions, 0);
      const evaluator = FeatureVariationEvaluator(<double>[0.0]);

      expect(evaluator.matches(record), isTrue);
    });

    test('rejects when any condition falls outside range', () {
      const conditions = <FeatureVariationCondition>[
        FeatureVariationCondition(0, -1.0, 0.0),
      ];
      const record = FeatureVariationRecord(conditions, 0);
      const evaluator = FeatureVariationEvaluator(<double>[0.5]);

      expect(evaluator.matches(record), isFalse);
    });
  });
}
