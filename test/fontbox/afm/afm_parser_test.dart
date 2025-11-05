import 'dart:convert';

import 'package:pdfbox_dart/src/fontbox/afm/afm_parser.dart';
import 'package:test/test.dart';

void main() {
  const sampleAfm = 'StartFontMetrics 4.1\n'
      'Comment Example Parser\n'
      'FontName FakeFont\n'
      'FullName Fake Font Regular\n'
      'FamilyName Fake Family\n'
      'Weight Medium\n'
      'FontBBox -50 -200 1000 900\n'
      'Version 001.003\n'
      'Notice Copyright (c) Example\n'
      'EncodingScheme StandardEncoding\n'
      'MappingScheme 2\n'
      'EscChar 123\n'
      'CharacterSet FakeSet\n'
      'Characters 2\n'
      'IsBaseFont true\n'
      'VVector 0 0\n'
      'IsFixedV true\n'
      'CapHeight 700\n'
      'XHeight 500\n'
      'Ascender 800\n'
      'Descender -200\n'
      'StdHW 50\n'
      'StdVW 80\n'
      'UnderlinePosition -100\n'
      'UnderlineThickness 50\n'
      'ItalicAngle -12.0\n'
      'CharWidth 600 0\n'
      'IsFixedPitch false\n'
      'StartCharMetrics 2\n'
      'C 65 ; WX 500 ; N A ; B 10 20 530 600 ; L B ffi ;\n'
      'C 66 ; WX 510 ; WY 250 ; W0X 10 ; W0Y 20 ; W1X 20 ; W1Y 30 ; '
      'W 400 0 ; W0 300 0 ; W1 200 0 ; VV 0 0 ; N B ; B 0 0 520 700 ;\n'
      'EndCharMetrics\n'
      'StartKernData\n'
      'StartTrackKern 1\n'
      '1 8 -10 12 -5\n'
      'EndTrackKern\n'
      'StartKernPairs 2\n'
      'KP A V -50 -10\n'
      'KPH <41> <56> -60 -20\n'
      'EndKernPairs\n'
      'StartKernPairs0 1\n'
      'KPX A T -30\n'
      'EndKernPairs\n'
      'StartKernPairs1 1\n'
      'KPY A W -20\n'
      'EndKernPairs\n'
      'EndKernData\n'
      'StartComposites 1\n'
      'CC Aacute 1 ; PCC A 0 0 ;\n'
      'EndComposites\n'
      'EndFontMetrics\n';

  group('AFMParser', () {
    test('parses complete dataset', () {
      final parser = AFMParser(latin1.encode(sampleAfm));
      final metrics = parser.parse();

      expect(metrics.getAFMVersion(), closeTo(4.1, 1e-6));
      expect(metrics.getFontName(), 'FakeFont');
      expect(metrics.getFullName(), 'Fake Font Regular');
      expect(metrics.getFamilyName(), 'Fake Family');
      expect(metrics.getWeight(), 'Medium');
      expect(metrics.getFontVersion(), '001.003');
      expect(metrics.getNotice(), 'Copyright (c) Example');
      expect(metrics.getEncodingScheme(), 'StandardEncoding');
      expect(metrics.getMappingScheme(), 2);
      expect(metrics.getEscChar(), 123);
      expect(metrics.getCharacterSet(), 'FakeSet');
      expect(metrics.getCharacters(), 2);
      expect(metrics.getIsBaseFont(), isTrue);
      expect(metrics.getVVector(), orderedEquals(<double>[0, 0]));
      expect(metrics.getIsFixedV(), isTrue);
      expect(metrics.getCapHeight(), closeTo(700, 1e-6));
      expect(metrics.getXHeight(), closeTo(500, 1e-6));
      expect(metrics.getAscender(), closeTo(800, 1e-6));
      expect(metrics.getDescender(), closeTo(-200, 1e-6));
      expect(metrics.getStandardHorizontalWidth(), closeTo(50, 1e-6));
      expect(metrics.getStandardVerticalWidth(), closeTo(80, 1e-6));
      expect(metrics.getUnderlinePosition(), closeTo(-100, 1e-6));
      expect(metrics.getUnderlineThickness(), closeTo(50, 1e-6));
      expect(metrics.getItalicAngle(), closeTo(-12, 1e-6));
      expect(metrics.getCharWidth(), orderedEquals(<double>[600, 0]));
      expect(metrics.getIsFixedPitch(), isFalse);

      final bbox = metrics.getFontBBox()!;
      expect(bbox.lowerLeftX, closeTo(-50, 1e-6));
      expect(bbox.lowerLeftY, closeTo(-200, 1e-6));
      expect(bbox.upperRightX, closeTo(1000, 1e-6));
      expect(bbox.upperRightY, closeTo(900, 1e-6));

      expect(metrics.getComments(), contains('Example Parser'));

      expect(metrics.getCharMetrics(), hasLength(2));
      final charA = metrics.getCharMetrics().firstWhere((m) => m.getName() == 'A');
      final charB = metrics.getCharMetrics().firstWhere((m) => m.getName() == 'B');

      expect(charA.getCharacterCode(), 65);
      expect(charA.getWx(), closeTo(500, 1e-6));
      expect(charA.getBoundingBox()!.lowerLeftX, closeTo(10, 1e-6));
      expect(charA.getBoundingBox()!.upperRightY, closeTo(600, 1e-6));
      expect(charA.getLigatures(), hasLength(1));
  expect(charA.getLigatures().single.successor, 'B');
  expect(charA.getLigatures().single.ligature, 'ffi');

      expect(charB.getWy(), closeTo(250, 1e-6));
      expect(charB.getW0x(), closeTo(10, 1e-6));
      expect(charB.getW0y(), closeTo(20, 1e-6));
      expect(charB.getW1x(), closeTo(20, 1e-6));
      expect(charB.getW1y(), closeTo(30, 1e-6));
      expect(charB.getW(), orderedEquals(<double>[400, 0]));
      expect(charB.getW0(), orderedEquals(<double>[300, 0]));
      expect(charB.getW1(), orderedEquals(<double>[200, 0]));
      expect(charB.getVv(), orderedEquals(<double>[0, 0]));
      expect(charB.getBoundingBox()!.upperRightY, closeTo(700, 1e-6));

      expect(metrics.getCharacterWidth('A'), closeTo(500, 1e-6));
      expect(metrics.getCharacterWidth('B'), closeTo(510, 1e-6));
      expect(metrics.getCharacterHeight('A'), closeTo(580, 1e-6));
      expect(metrics.getCharacterHeight('B'), closeTo(250, 1e-6));
      expect(metrics.getAverageCharacterWidth(), closeTo(505, 1e-6));

      expect(metrics.getTrackKern(), hasLength(1));
      final track = metrics.getTrackKern().single;
      expect(track.degree, 1);
      expect(track.minPointSize, closeTo(8, 1e-6));
      expect(track.minKern, closeTo(-10, 1e-6));
      expect(track.maxPointSize, closeTo(12, 1e-6));
      expect(track.maxKern, closeTo(-5, 1e-6));

  expect(metrics.getKernPairs(), hasLength(2));
  final firstPair = metrics.getKernPairs().first;
  final secondPair = metrics.getKernPairs().last;
  expect(firstPair.firstKernCharacter, 'A');
  expect(firstPair.x, closeTo(-50, 1e-6));
  expect(firstPair.y, closeTo(-10, 1e-6));
  expect(secondPair.firstKernCharacter, 'A');
  expect(secondPair.x, closeTo(-60, 1e-6));
  expect(secondPair.y, closeTo(-20, 1e-6));

  expect(metrics.getKernPairs0(), hasLength(1));
  expect(metrics.getKernPairs0().single.x, closeTo(-30, 1e-6));
  expect(metrics.getKernPairs0().single.y, closeTo(0, 1e-6));

  expect(metrics.getKernPairs1(), hasLength(1));
  expect(metrics.getKernPairs1().single.x, closeTo(0, 1e-6));
  expect(metrics.getKernPairs1().single.y, closeTo(-20, 1e-6));

  expect(metrics.getComposites(), hasLength(1));
  final composite = metrics.getComposites().single;
  expect(composite.name, 'Aacute');
  expect(composite.parts, hasLength(1));
  expect(composite.parts.single.name, 'A');
  expect(composite.parts.single.xDisplacement, 0);
  expect(composite.parts.single.yDisplacement, 0);
    });

    test('reduced dataset skips kerning and composites', () {
      final parser = AFMParser(latin1.encode(sampleAfm));
      final metrics = parser.parse(reducedDataset: true);

      expect(metrics.getCharMetrics(), hasLength(2));
      expect(metrics.getTrackKern(), isEmpty);
      expect(metrics.getKernPairs(), isEmpty);
      expect(metrics.getKernPairs0(), isEmpty);
      expect(metrics.getKernPairs1(), isEmpty);
      expect(metrics.getComposites(), isEmpty);
    });
  });
}
