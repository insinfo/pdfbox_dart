import 'package:pdfbox_dart/src/fontbox/afm/char_metric.dart';
import 'package:pdfbox_dart/src/fontbox/afm/font_metrics.dart';
import 'package:pdfbox_dart/src/fontbox/afm/track_kern.dart';
import 'package:pdfbox_dart/src/fontbox/util/bounding_box.dart';
import 'package:test/test.dart';

void main() {
  group('FontMetrics', () {
    test('character width, height, and averages mirror AFM semantics', () {
      final metrics = FontMetrics();

      expect(metrics.getCharacterWidth('A'), equals(0));
      expect(metrics.getCharacterHeight('A'), equals(0));

      final aMetric = CharMetric()
        ..setName('A')
        ..setWx(500)
        ..setWy(0)
        ..setBoundingBox(BoundingBox.fromValues(0, 0, 500, 700));
      metrics.addCharMetric(aMetric);

      final bMetric = CharMetric()
        ..setName('B')
        ..setWx(0)
        ..setWy(250);
      metrics.addCharMetric(bMetric);

      expect(metrics.getCharacterWidth('A'), closeTo(500, 1e-6));
      expect(metrics.getCharacterHeight('A'), closeTo(700, 1e-6));
      expect(metrics.getCharacterHeight('B'), closeTo(250, 1e-6));
      expect(metrics.getAverageCharacterWidth(), closeTo(500, 1e-6));
    });

    test('metric sets and vertical vector follow Java behaviour', () {
      final metrics = FontMetrics();

      expect(() => metrics.setMetricSets(-1), throwsArgumentError);
      metrics.setMetricSets(2);
      expect(metrics.getMetricSets(), equals(2));

      expect(metrics.getIsFixedV(), isFalse);
      metrics.setVVector([120, -30]);
      expect(metrics.getIsFixedV(), isTrue);
      metrics.setIsFixedV(false);
      expect(metrics.getIsFixedV(), isFalse);
    });

    test('exposed collections are immutable views', () {
      final metrics = FontMetrics();
      metrics.addComment('note');
      expect(() => metrics.getComments().add('more'), throwsUnsupportedError);

      final charMetric = CharMetric()..setName('X');
      metrics.addCharMetric(charMetric);
      expect(() => metrics.getCharMetrics().add(CharMetric()), throwsUnsupportedError);

      metrics.addTrackKern(TrackKern(1, 8, -10, 12, -5));
      expect(() => metrics.getTrackKern().add(TrackKern(0, 0, 0, 0, 0)), throwsUnsupportedError);
    });
  });
}
