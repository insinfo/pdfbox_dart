import 'package:pdfbox_dart/src/fontbox/ttf/glyph_renderer.dart';
import 'package:test/test.dart';

void main() {
  test('records cubic curve segments', () {
    final path = GlyphPath();
    path.moveTo(0, 0);
    path.curveTo(10, 20, 30, 40, 50, 60);

    expect(path.commands, hasLength(2));
    final command = path.commands[1];
    expect(command, isA<CubicToCommand>());
    final cubic = command as CubicToCommand;
    expect(cubic.cx1, equals(10));
    expect(cubic.cy1, equals(20));
    expect(cubic.cx2, equals(30));
    expect(cubic.cy2, equals(40));
    expect(cubic.x, equals(50));
    expect(cubic.y, equals(60));
  });
}
