import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/cff/cff_charset.dart';
import 'package:pdfbox_dart/src/fontbox/cff/cff_font.dart';

class ConstantFdSelect implements CFFFDSelect {
  const ConstantFdSelect(this.index);

  final int index;

  @override
  int getFDIndex(int gid) => index;
}

CFFCIDFont createSimpleCidFont() {
  final font = CFFCIDFont()
    ..name = 'CIDFont'
    ..charset = EmbeddedCharset(isCidFont: true)
    ..charStrings = <Uint8List>[]
    ..globalSubrIndex = <Uint8List>[]
    ..fontDicts = <Map<String, Object?>>[<String, Object?>{}]
    ..privateDicts = <Map<String, Object?>>[
      <String, Object?>{
        'defaultWidthX': 1000,
        'nominalWidthX': 0,
        'Subrs': <Uint8List>[],
      },
    ]
    ..fdSelect = const ConstantFdSelect(0);

  font.topDict['FontBBox'] = <num>[-50, -250, 1200, 950];
  font.topDict['FontMatrix'] = const <num>[0.001, 0, 0, 0.001, 0, 0];

  final charset = font.charset as EmbeddedCharset;
  charset.addCID(0, 0);
  charset.addCID(1, 1);
  charset.addCID(2, 2);

  final notdef = Uint8List.fromList(<int>[14]);
  final glyph =
      Uint8List.fromList(<int>[248, 236, 239, 247, 92, 21, 189, 6, 14]);
  final glyphTwo =
      Uint8List.fromList(<int>[248, 236, 239, 247, 92, 21, 189, 6, 14]);
  font.charStrings = <Uint8List>[notdef, glyph, glyphTwo];

  return font;
}
