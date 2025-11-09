import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/type1/type1_font.dart';
import 'package:test/test.dart';

void main() {
  Uint8List _buildSegment(int type, Uint8List data) {
    final buffer = BytesBuilder();
    buffer.add(<int>[0x80, type]);
    final length = data.length;
    buffer
      ..add(<int>[
        length & 0xFF,
        (length >> 8) & 0xFF,
        (length >> 16) & 0xFF,
        (length >> 24) & 0xFF,
      ])
      ..add(data);
    return buffer.toBytes();
  }

  Uint8List _encryptEexec(Uint8List plain) {
    const c1 = 52845;
    const c2 = 22719;
    final prefixed = Uint8List(4 + plain.length);
    prefixed.setRange(0, 4, const <int>[0x00, 0x00, 0x00, 0x00]);
    prefixed.setRange(4, prefixed.length, plain);

    final cipher = Uint8List(prefixed.length);
    var r = 55665;
    for (var i = 0; i < prefixed.length; i++) {
      final plainByte = prefixed[i];
      final cipherByte = (plainByte ^ (r >> 8)) & 0xFF;
      cipher[i] = cipherByte;
      r = ((cipherByte + r) * c1 + c2) & 0xFFFF;
    }
    return cipher;
  }

  Uint8List _encryptCharString(Uint8List plain, {int lenIV = 4}) {
    const c1 = 52845;
    const c2 = 22719;
    final prefixed = Uint8List(lenIV + plain.length);
    for (var i = 0; i < lenIV; i++) {
      prefixed[i] = i;
    }
    prefixed.setRange(lenIV, prefixed.length, plain);

    final cipher = Uint8List(prefixed.length);
    var r = 4330;
    for (var i = 0; i < prefixed.length; i++) {
      final plainByte = prefixed[i];
      final cipherByte = (plainByte ^ (r >> 8)) & 0xFF;
      cipher[i] = cipherByte;
      r = ((cipherByte + r) * c1 + c2) & 0xFFFF;
    }
    return cipher;
  }

  test('parses minimal Type 1 font from PFB container', () {
    final asciiSegment = '''%!FontType1-1.0
11 dict begin
/FontName /TestFont def
/PaintType 0 def
/FontType 1 def
/FontMatrix [0.001 0 0 0.001 0 0] def
/FontBBox [0 0 1000 1000] def
/Encoding StandardEncoding def
currentdict end
currentfile eexec
'''
        .codeUnits;

    final notdefCharString = Uint8List.fromList(<int>[139, 139, 13, 14]);
    final binaryPlain = BytesBuilder()
      ..add('/Private 1 dict dup begin\n'.codeUnits)
      ..add('  /lenIV -1 def\n'.codeUnits)
      ..add('  /Subrs 0 array def\n'.codeUnits)
      ..add('end\n'.codeUnits)
      ..add('/CharStrings 1 dict dup begin\n'.codeUnits)
      ..add('  /.notdef 4 RD '.codeUnits)
      ..add(notdefCharString)
      ..add(' def\n'.codeUnits)
      ..add('end\n'.codeUnits)
      ..add('end\n'.codeUnits);
    final binarySegment = _encryptEexec(binaryPlain.toBytes());

    final finalSegment = 'cleartomark\n'.codeUnits;

    final pfbBytes = BytesBuilder()
      ..add(_buildSegment(0x01, Uint8List.fromList(asciiSegment)))
      ..add(_buildSegment(0x02, binarySegment))
      ..add(_buildSegment(0x01, Uint8List.fromList(finalSegment)))
      ..add(<int>[0x80, 0x03]);

    final font = Type1Font.createWithPfb(pfbBytes.toBytes());

    expect(font.getFontName(), 'TestFont');
    expect(font.getEncoding(), isNotNull);
    expect(font.getPaintType(), equals(0));
    expect(font.getFontType(), equals(1));
    expect(font.getFontID(), isEmpty);
    expect(font.getUniqueID(), equals(0));
    expect(font.isFixedPitch(), isFalse);
    expect(font.hasGlyph('.notdef'), isTrue);
    expect(font.getWidth('.notdef'), 0);

    final bbox = font.getFontBBox();
    expect(bbox.lowerLeftX, closeTo(0, 1e-6));
    expect(bbox.lowerLeftY, closeTo(0, 1e-6));
    expect(bbox.upperRightX, closeTo(1000, 1e-6));
    expect(bbox.upperRightY, closeTo(1000, 1e-6));

    expect(font.getFontMatrix(),
        orderedEquals(<num>[0.001, 0.0, 0.0, 0.001, 0.0, 0.0]));

    expect(font.getCharStringsDict().containsKey('.notdef'), isTrue);
    expect(font.getSubrsArray(), isEmpty);

    expect(font.getASCIISegment(), equals(Uint8List.fromList(asciiSegment)));
    expect(font.getBinarySegment(), equals(binarySegment));

    final charString = font.getType1CharString('.notdef');
    expect(charString.getPath().commands, isEmpty);
    expect(charString.getWidth(), 0);
  });

  test('decrypts charstrings when lenIV is positive and falls back to .notdef',
      () {
    final asciiSegment = '''%!FontType1-1.0
11 dict begin
/FontName /TestLenIV def
/PaintType 0 def
/FontType 1 def
/FontMatrix [0.001 0 0 0.001 0 0] def
/FontBBox [0 0 1000 1000] def
/Encoding StandardEncoding def
currentdict end
currentfile eexec
'''
        .codeUnits;

    final notdefPlain = Uint8List.fromList(<int>[139, 139, 13, 14]);
    final encryptedNotdef = _encryptCharString(notdefPlain);

    final binaryPlain = BytesBuilder()
      ..add('/Private 1 dict dup begin\n'.codeUnits)
      ..add('  /lenIV 4 def\n'.codeUnits)
      ..add('  /Subrs 0 array def\n'.codeUnits)
      ..add('end\n'.codeUnits)
      ..add('/CharStrings 1 dict dup begin\n'.codeUnits)
      ..add('  /.notdef ${encryptedNotdef.length} RD '.codeUnits)
      ..add(encryptedNotdef)
      ..add(' def\n'.codeUnits)
      ..add('end\n'.codeUnits)
      ..add('end\n'.codeUnits);

    final binarySegment = _encryptEexec(binaryPlain.toBytes());
    final finalSegment = 'cleartomark\n'.codeUnits;

    final pfbBytes = BytesBuilder()
      ..add(_buildSegment(0x01, Uint8List.fromList(asciiSegment)))
      ..add(_buildSegment(0x02, binarySegment))
      ..add(_buildSegment(0x01, Uint8List.fromList(finalSegment)))
      ..add(<int>[0x80, 0x03]);

    final font = Type1Font.createWithPfb(pfbBytes.toBytes());

    expect(font.getFontName(), 'TestLenIV');
    expect(font.getCharStringsDict()['.notdef'], equals(notdefPlain));
    expect(font.getSubrsArray(), isEmpty);

    expect(font.hasGlyph('MissingGlyph'), isFalse);
    final notdef = font.getType1CharString('.notdef');
    final fallback = font.getType1CharString('MissingGlyph');
    expect(fallback.getWidth(), 0);
    expect(fallback.getPath().commands, equals(notdef.getPath().commands));
  });

  test('populates subroutines and resolves callsubr operators', () {
    final asciiSegment = '''%!FontType1-1.0
11 dict begin
/FontName /TestSubrs def
/PaintType 0 def
/FontType 1 def
/FontMatrix [0.001 0 0 0.001 0 0] def
/FontBBox [0 0 1000 1000] def
/Encoding StandardEncoding def
currentdict end
currentfile eexec
'''
        .codeUnits;

    final subrPlain = Uint8List.fromList(<int>[139, 139, 13, 14]);
  final glyphPlain = Uint8List.fromList(<int>[139, 139, 10, 14]);

    final subrEncrypted = _encryptCharString(subrPlain);
    final glyphEncrypted = _encryptCharString(glyphPlain);

    final binaryPlain = BytesBuilder()
      ..add('/Private 2 dict dup begin\n'.codeUnits)
      ..add('  /Subrs 1 array\n'.codeUnits)
      ..add('  dup 0 ${subrEncrypted.length} RD '.codeUnits)
      ..add(subrEncrypted)
      ..add(' NP\n'.codeUnits)
      ..add('  noaccess def\n'.codeUnits)
      ..add('  /lenIV 4 def\n'.codeUnits)
      ..add('end\n'.codeUnits)
      ..add('/CharStrings 1 dict dup begin\n'.codeUnits)
      ..add('  /.notdef ${glyphEncrypted.length} RD '.codeUnits)
      ..add(glyphEncrypted)
      ..add(' def\n'.codeUnits)
      ..add('end\n'.codeUnits)
      ..add('end\n'.codeUnits);

    final binarySegment = _encryptEexec(binaryPlain.toBytes());
    final finalSegment = 'cleartomark\n'.codeUnits;

    final pfbBytes = BytesBuilder()
      ..add(_buildSegment(0x01, Uint8List.fromList(asciiSegment)))
      ..add(_buildSegment(0x02, binarySegment))
      ..add(_buildSegment(0x01, Uint8List.fromList(finalSegment)))
      ..add(<int>[0x80, 0x03]);

    final font = Type1Font.createWithPfb(pfbBytes.toBytes());

    expect(font.getFontName(), 'TestSubrs');
    expect(font.getSubrsArray(), hasLength(1));
    expect(font.getSubrsArray().first, equals(subrPlain));

    final notdef = font.getType1CharString('.notdef');
    expect(notdef.getWidth(), 0);
    expect(notdef.getPath().commands.length, equals(0));
  });
}
