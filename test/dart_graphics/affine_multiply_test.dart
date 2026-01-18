import 'package:dart_graphics/dart_graphics.dart';
import 'package:test/test.dart';

Affine _mulExpectedLikeDartGraphics(Affine current, Affine m) {
  // Mirrors dart_graphics' Affine.multiply implementation exactly.
  final t0 = current.sx * m.sx + current.shy * m.shx;
  final t2 = current.shx * m.sx + current.sy * m.shx;
  final t4 = current.tx * m.sx + current.ty * m.shx + m.tx;

  final shy = current.sx * m.shy + current.shy * m.sy;
  final sy = current.shx * m.shy + current.sy * m.sy;
  final ty = current.tx * m.shy + current.ty * m.sy + m.ty;

  return Affine(t0, shy, t2, sy, t4, ty);
}

({double x, double y}) _apply(Affine m, double x, double y) {
  return (
    x: m.sx * x + m.shx * y + m.tx,
    y: m.shy * x + m.sy * y + m.ty,
  );
}

void _expectAffineClose(Affine actual, Affine expected, {double eps = 1e-9}) {
  expect(actual.sx, closeTo(expected.sx, eps), reason: 'sx');
  expect(actual.shy, closeTo(expected.shy, eps), reason: 'shy');
  expect(actual.shx, closeTo(expected.shx, eps), reason: 'shx');
  expect(actual.sy, closeTo(expected.sy, eps), reason: 'sy');
  expect(actual.tx, closeTo(expected.tx, eps), reason: 'tx');
  expect(actual.ty, closeTo(expected.ty, eps), reason: 'ty');
}

void main() {
  test('dart_graphics Affine.multiply matches implementation', () {
    final a = Affine(2, 0.25, -0.5, 3, 10, 20);
    final b = Affine(1.5, -0.75, 0.5, 2, 5, -7);

    final expected = _mulExpectedLikeDartGraphics(a, b);
    final actual = Affine(a.sx, a.shy, a.shx, a.sy, a.tx, a.ty)..multiply(b);

    _expectAffineClose(actual, expected);
  });

  test('dart_graphics Affine.multiply composes transforms consistently on points', () {
    final a = Affine(0.1, 0, 0, 0.1, 0, 0); // scale 0.1
    final b = Affine(1, 0, 0, 1, 30, 30); // translate (30,30)

    // In terms of points: (a.multiply(b))(p) == b(a(p)).
    // i.e. the newly multiplied transform is applied last.
    final composed = Affine(a.sx, a.shy, a.shx, a.sy, a.tx, a.ty)..multiply(b);

    final p = (x: 0.0, y: 0.0);
    final afterA = _apply(a, p.x, p.y);
    final sequential = _apply(b, afterA.x, afterA.y);
    final direct = _apply(composed, p.x, p.y);

    expect(direct.x, closeTo(sequential.x, 1e-9));
    expect(direct.y, closeTo(sequential.y, 1e-9));

    // Translation should NOT be scaled when applying scale then translate.
    expect(direct.x, closeTo(30.0, 1e-9));
    expect(direct.y, closeTo(30.0, 1e-9));
  });
}
