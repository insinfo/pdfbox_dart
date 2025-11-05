import 'package:pdfbox_dart/src/fontbox/util/bounding_box.dart';
import 'package:test/test.dart';

void main() {
  group('BoundingBox', () {
    test('width and height reflect corner updates', () {
      final bbox = BoundingBox.fromValues(10, 20, 40, 70);
      expect(bbox.width, closeTo(30, 1e-6));
      expect(bbox.height, closeTo(50, 1e-6));

      bbox.lowerLeftX = 5;
      bbox.upperRightY = 65;
      expect(bbox.width, closeTo(35, 1e-6));
      expect(bbox.height, closeTo(45, 1e-6));
    });

    test('contains matches Java semantics', () {
      final bbox = BoundingBox.fromValues(0, 0, 100, 50);
      expect(bbox.contains(0, 0), isTrue);
      expect(bbox.contains(50, 25), isTrue);
      expect(bbox.contains(100, 50), isTrue);
      expect(bbox.contains(-1, 25), isFalse);
      expect(bbox.contains(50, 51), isFalse);
    });

    test('fromNumbers validates input length', () {
      final bbox = BoundingBox.fromNumbers([1, 2, 3, 4]);
      expect(bbox.lowerLeftX, closeTo(1, 1e-6));
      expect(bbox.lowerLeftY, closeTo(2, 1e-6));
      expect(bbox.upperRightX, closeTo(3, 1e-6));
      expect(bbox.upperRightY, closeTo(4, 1e-6));
      expect(() => BoundingBox.fromNumbers([0, 1, 2]), throwsArgumentError);
    });

    test('toString mirrors FontBox output', () {
      final bbox = BoundingBox.fromValues(1.5, -2, 3.25, 4.75);
      expect(bbox.toString(), '[1.5,-2.0,3.25,4.75]');
    });
  });
}
