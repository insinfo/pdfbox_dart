import 'dart:math' as math;

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/shading/pd_shading.dart';

void main() {
  group('ShadingVertex', () {
    test('creates a vertex with point and color', () {
      final v = ShadingVertex(const Point(1.5, 2.5), [0.5, 0.6, 0.7]);
      expect(v.point.x, 1.5);
      expect(v.point.y, 2.5);
      expect(v.color, [0.5, 0.6, 0.7]);
    });

    test('color is a copy, not shared', () {
      final original = [0.5, 0.6];
      final v = ShadingVertex(const Point(0, 0), original);
      original[0] = 0.99;
      expect(v.color[0], 0.5);
    });
  });

  group('ShadingLine', () {
    test('calculates line points between two points', () {
      final line = ShadingLine(
        const IntPoint(0, 0),
        const IntPoint(5, 0),
        [1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0],
      );
      // Horizontal line should have 6 points (0..5)
      expect(line.linePoints.length, 6);
      expect(line.linePoints.contains(const IntPoint(0, 0)), isTrue);
      expect(line.linePoints.contains(const IntPoint(5, 0)), isTrue);
    });

    test('interpolates color along line', () {
      final line = ShadingLine(
        const IntPoint(0, 0),
        const IntPoint(4, 0),
        [1.0, 0.0],
        [0.0, 1.0],
      );
      // Midpoint should be 0.5, 0.5
      final midColor = line.calcColor(const IntPoint(2, 0));
      expect(midColor[0], closeTo(0.5, 0.01));
      expect(midColor[1], closeTo(0.5, 0.01));
    });
  });

  group('ShadedTriangle', () {
    test('creates triangle with corners and colors', () {
      final tri = ShadedTriangle(
        [const Point(0, 0), const Point(10, 0), const Point(5, 10)],
        [
          [1.0, 0.0, 0.0],
          [0.0, 1.0, 0.0],
          [0.0, 0.0, 1.0]
        ],
      );
      expect(tri.corner.length, 3);
      expect(tri.color.length, 3);
      expect(tri.deg, 3); // Normal triangle
    });

    test('contains point inside triangle', () {
      final tri = ShadedTriangle(
        [const Point(0, 0), const Point(10, 0), const Point(5, 10)],
        [
          [1.0],
          [0.0],
          [0.0]
        ],
      );
      // Center of triangle
      expect(tri.contains(const Point(5, 3)), isTrue);
      // Outside
      expect(tri.contains(const Point(-5, -5)), isFalse);
    });

    test('calcColor returns interpolated color at center', () {
      final tri = ShadedTriangle(
        [const Point(0, 0), const Point(10, 0), const Point(5, 10)],
        [
          [1.0, 0.0, 0.0],
          [0.0, 1.0, 0.0],
          [0.0, 0.0, 1.0]
        ],
      );
      // Centroid at (5, 3.33...)
      final centroid = const Point(5, 10 / 3);
      final color = tri.calcColor(centroid);
      // All three colors should contribute roughly equally
      expect(color[0], closeTo(0.33, 0.1));
      expect(color[1], closeTo(0.33, 0.1));
      expect(color[2], closeTo(0.33, 0.1));
    });

    test('getBoundary returns correct bounds', () {
      final tri = ShadedTriangle(
        [const Point(2, 3), const Point(8, 5), const Point(4, 9)],
        [
          [1.0],
          [0.0],
          [0.5]
        ],
      );
      final bounds = tri.getBoundary();
      expect(bounds[0], 2); // xmin
      expect(bounds[1], 8); // xmax
      expect(bounds[2], 3); // ymin
      expect(bounds[3], 9); // ymax
    });

    test('degenerates to line when two points overlap', () {
      final tri = ShadedTriangle(
        [const Point(0, 0), const Point(0, 0), const Point(5, 0)],
        [
          [1.0],
          [1.0],
          [0.0]
        ],
      );
      expect(tri.deg, 2);
      expect(tri.line, isNotNull);
    });

    test('degenerates to point when all points overlap', () {
      final tri = ShadedTriangle(
        [const Point(3, 3), const Point(3, 3), const Point(3, 3)],
        [
          [1.0],
          [1.0],
          [1.0]
        ],
      );
      expect(tri.deg, 1);
    });
  });

  group('BitInputStream', () {
    test('reads bits correctly', () {
      // Binary: 11110000 10101010 = 0xF0 0xAA
      final stream = BitInputStream([0xF0, 0xAA]);

      expect(stream.readBits(4), 0xF); // 1111
      expect(stream.readBits(4), 0x0); // 0000
      expect(stream.readBits(8), 0xAA); // 10101010
    });

    test('reads across byte boundaries', () {
      // 11110001 00110011 = 0xF1 0x33
      final stream = BitInputStream([0xF1, 0x33]);

      // First 5 bits: 11110 = 30 (0x1E)
      expect(stream.readBits(5), 0x1E);
      // Next 6 bits: 001 + 001 = 001001 = 9
      expect(stream.readBits(6), 9);
    });

    test('detects EOF correctly', () {
      final stream = BitInputStream([0xFF]);
      expect(stream.isEof, isFalse);
      stream.readBits(8);
      expect(stream.isEof, isTrue);
    });
  });

  group('PDRange', () {
    test('returns min and max from COSArray', () {
      final arr = COSArray()
        ..add(COSFloat(0.5))
        ..add(COSFloat(2.5));
      final range = PDRange(arr, 0);
      expect(range.min, 0.5);
      expect(range.max, 2.5);
    });
  });

  group('CubicBezierCurve', () {
    test('evaluates curve points', () {
      final pts = [
        const Point(0, 0),
        const Point(0, 10),
        const Point(10, 10),
        const Point(10, 0),
      ];
      final curve = CubicBezierCurve(pts, 1); // 2^1 + 1 = 3 points
      final result = curve.getCubicBezierCurve();
      expect(result.length, 3);
      // First point should be start
      expect(result[0].x, closeTo(0, 0.01));
      expect(result[0].y, closeTo(0, 0.01));
      // Last point should be end
      expect(result[2].x, closeTo(10, 0.01));
      expect(result[2].y, closeTo(0, 0.01));
    });
  });

  group('CoonsPatch', () {
    test('creates triangle list from 12 control points', () {
      // Create a simple quad-like patch
      final points = <Point>[];
      // 12 control points for Coons patch around a simple square
      for (var i = 0; i < 12; i++) {
        final angle = i * 2 * 3.14159 / 12;
        points.add(Point(50 + 40 * math.cos(angle), 50 + 40 * math.sin(angle)));
      }

      final colors = [
        [1.0, 0.0, 0.0], // corner 0
        [0.0, 1.0, 0.0], // corner 1
        [0.0, 0.0, 1.0], // corner 2
        [1.0, 1.0, 0.0], // corner 3
      ];

      final patch = CoonsPatch(points, colors);
      expect(patch.listOfTriangles, isNotEmpty);
    });
  });

  group('TensorPatch', () {
    test('creates triangle list from 16 control points', () {
      // Create 16 control points for tensor patch (4x4 grid)
      final points = <Point>[];
      for (var i = 0; i < 16; i++) {
        final x = (i % 4) * 25.0;
        final y = (i ~/ 4) * 25.0;
        points.add(Point(x, y));
      }

      final colors = [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0],
        [1.0, 1.0, 0.0],
      ];

      final patch = TensorPatch(points, colors);
      expect(patch.listOfTriangles, isNotEmpty);
    });
  });
}
