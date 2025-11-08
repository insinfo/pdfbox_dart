import 'package:pdfbox_dart/src/fontbox/cff/char_string_command.dart';
import 'package:pdfbox_dart/src/fontbox/cff/char_string_path.dart';
import 'package:pdfbox_dart/src/fontbox/cff/type1_char_string.dart';
import 'package:pdfbox_dart/src/fontbox/cff/type2_char_string.dart';
import 'package:pdfbox_dart/src/fontbox/type1/type1_char_string_reader.dart';
import 'package:test/test.dart';

class _StubCharStringReader implements Type1CharStringReader {
  @override
  Type1CharString getType1CharString(String name) {
    return Type1CharString(this, 'StubFont', name, const <Object>[]);
  }
}

void main() {
  group('Type2CharString', () {
    test('converts basic outline commands', () {
      final reader = _StubCharStringReader();
      final sequence = <Object>[
        600,
        150,
        200,
        CharStringCommand.rmoveto,
        50,
        CharStringCommand.hlineto,
        30,
        40,
        50,
        60,
        70,
        80,
        CharStringCommand.rrcurveto,
        CharStringCommand.endchar,
      ];

      final charString = Type2CharString(
        reader,
        'StubFont',
        'GID+0',
        0,
        sequence,
        1000,
        0,
      );

      expect(charString.gidValue, 0);
      expect(charString.getWidth(), closeTo(600, 1e-6));

  final path = charString.getPath();
  expect(path.commands.length, greaterThanOrEqualTo(3));

  final move = path.commands[0];
      expect(move, isA<MoveToCommand>());
      move as MoveToCommand;
      expect(move.x, closeTo(150, 1e-6));
      expect(move.y, closeTo(200, 1e-6));

  final line = path.commands[1];
      expect(line, isA<LineToCommand>());
      line as LineToCommand;
      expect(line.x, closeTo(200, 1e-6));
      expect(line.y, closeTo(200, 1e-6));

  final curve = path.commands[2];
      expect(curve, isA<CurveToCommand>());
      curve as CurveToCommand;
      expect(curve.x1, closeTo(230, 1e-6));
      expect(curve.y1, closeTo(240, 1e-6));
      expect(curve.x2, closeTo(280, 1e-6));
      expect(curve.y2, closeTo(300, 1e-6));
      expect(curve.x3, closeTo(350, 1e-6));
      expect(curve.y3, closeTo(380, 1e-6));
    });
  });
}
