import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyf/glyph_description.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyf/glyf_composite_comp.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyf/glyf_composite_descript.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyf/glyf_descript.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyf/glyf_simple_descript.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyph_data.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyph_renderer.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyph_table.dart';
import 'package:test/test.dart';

void main() {
  group('GlyfSimpleDescript', () {
    test('decodes simple glyph with constant and short coordinate deltas', () {
      final dataBytes = Uint8List.fromList(<int>[
        0x00, 0x01, // endPtsOfContours[0] = 1
        0x00, 0x00, // instructionCount = 0
        0x01, // point 0 flag: on-curve, 16-bit deltas
        0x33, // point 1 flag: on-curve + X short (positive) + Y dual (zero delta)
        0x00, 0x00, // point 0 x delta
        0x0A, // point 1 x short delta (+10)
        0x00, 0x00, // point 0 y delta
      ]);
      final stream = RandomAccessReadDataStream.fromData(dataBytes);
      final glyph = GlyfSimpleDescript(1, stream, 0);

      expect(glyph.pointCount, 2);
      expect(glyph.contourCount, 1);
      expect(glyph.getEndPtOfContours(0), 1);
      expect(glyph.getXCoordinate(0), 0);
      expect(glyph.getXCoordinate(1), 10);
      expect(glyph.getYCoordinate(0), 0);
      expect(glyph.getYCoordinate(1), 0);
      expect(glyph.getFlags(0) & GlyfDescript.ON_CURVE, isNonZero);
      expect(glyph.getFlags(1) & GlyfDescript.X_SHORT_VECTOR, isNonZero);
    });

    test('GlyphRenderer generates line segments for simple contour', () {
      final dataBytes = Uint8List.fromList(<int>[
        0x00, 0x01,
        0x00, 0x00,
        0x01,
        0x33,
        0x00, 0x00,
        0x0A,
        0x00, 0x00,
      ]);
      final stream = RandomAccessReadDataStream.fromData(dataBytes);
      final glyph = GlyfSimpleDescript(1, stream, 0);
      final renderer = GlyphRenderer(glyph);

      final path = renderer.getPath();
      expect(path.isEmpty, isFalse);
      expect(path.commands.length, 4);
      expect(path.commands[0], isA<MoveToCommand>());
      expect(path.commands[1], isA<LineToCommand>());
      expect(path.commands[2], isA<LineToCommand>());
      expect(path.commands[3], isA<ClosePathCommand>());

      final moveTo = path.commands[0] as MoveToCommand;
      final firstLine = path.commands[1] as LineToCommand;
      final returnLine = path.commands[2] as LineToCommand;

      expect(moveTo.x, 0);
      expect(moveTo.y, 0);
      expect(firstLine.x, 10);
      expect(firstLine.y, 0);
      expect(returnLine.x, 0);
      expect(returnLine.y, 0);
    });
  });

  group('GlyfComposite structures', () {
    test('GlyfCompositeComp parses translations and scaling', () {
      final compBytes = Uint8List.fromList(<int>[
        0x00, 0x0B, // flags: words + xy values + scale
        0x00, 0x05, // glyph index 5
        0x00, 0x64, // argument1 = 100
        0xFF, 0xCE, // argument2 = -50
        0x40, 0x00, // scale = 1.0
      ]);
      final stream = RandomAccessReadDataStream.fromData(compBytes);
      final component = GlyfCompositeComp(stream);

      expect(component.glyphIndex, 5);
      expect(component.xTranslate, 100);
      expect(component.yTranslate, -50);
      expect(component.xScale, closeTo(1.0, 1e-9));
      expect(component.yScale, closeTo(1.0, 1e-9));
      expect(component.scaleX(12, -3), 12);
      expect(component.scaleY(12, -3), -3);
    });

    test('GlyfCompositeDescript resolves component indices and coordinates', () {
      final compositeBytes = Uint8List.fromList(<int>[
        0x00, 0x23, // flags: words + xy values + more components
        0x00, 0x01, // glyph index 1
        0x00, 0x00, // arg1 = 0
        0x00, 0x00, // arg2 = 0
        0x00, 0x03, // flags: words + xy values
        0x00, 0x02, // glyph index 2
        0x00, 0x0A, // arg1 = 10
        0x00, 0x00, // arg2 = 0
      ]);
      final stream = RandomAccessReadDataStream.fromData(compositeBytes);

      final glyphs = <int, GlyphDescription>{
        1: StubGlyphDescription(
          flags: const <int>[0, 0],
          xCoords: const <int>[0, 5],
          yCoords: const <int>[0, 5],
          contourEndpoints: const <int>[1],
        ),
        2: StubGlyphDescription(
          flags: const <int>[0, 0, 0],
          xCoords: const <int>[1, 2, 3],
          yCoords: const <int>[7, 7, 7],
          contourEndpoints: const <int>[2],
        ),
      };
      final table = FakeGlyphTable(glyphs);
      final composite = GlyfCompositeDescript(stream, table, 0);

      final components = composite.components;
      expect(components.length, 2);
      expect(() => components.removeAt(0), throwsUnsupportedError);

      composite.resolve();

      expect(components[0].firstIndex, 0);
      expect(components[1].firstIndex, 2);
      expect(components[1].firstContour, 1);
      expect(composite.pointCount, 5);
      expect(composite.contourCount, 2);
      expect(composite.getEndPtOfContours(1), 4);
      expect(composite.getXCoordinate(2), 11); // first point of second component + translation
      expect(composite.getYCoordinate(2), 7);
    });
  });
  group('GlyphData', () {
    test('empty glyph produces empty path', () {
      final glyphData = GlyphData()..initEmptyData();
      final path = glyphData.getPath();
      expect(path.isEmpty, isTrue);
      expect(path.commands, isEmpty);
    });
  });
}

class StubGlyphDescription implements GlyphDescription {
  StubGlyphDescription({
    required List<int> flags,
    required List<int> xCoords,
    required List<int> yCoords,
    required List<int> contourEndpoints,
  })  : _flags = flags,
        _xCoords = xCoords,
        _yCoords = yCoords,
        _contourEndpoints = contourEndpoints;

  final List<int> _flags;
  final List<int> _xCoords;
  final List<int> _yCoords;
  final List<int> _contourEndpoints;

  @override
  int getEndPtOfContours(int contourIndex) => _contourEndpoints[contourIndex];

  @override
  int getFlags(int pointIndex) => _flags[pointIndex];

  @override
  int getXCoordinate(int pointIndex) => _xCoords[pointIndex];

  @override
  int getYCoordinate(int pointIndex) => _yCoords[pointIndex];

  @override
  bool get isComposite => false;

  @override
  int get pointCount => _xCoords.length;

  @override
  int get contourCount => _contourEndpoints.length;

  @override
  void resolve() {}
}

class FakeGlyphTable extends GlyphTable {
  FakeGlyphTable(this._glyphs);

  final Map<int, GlyphDescription> _glyphs;

  @override
  GlyphData? getGlyph(int gid, [int level = 0]) {
    final description = _glyphs[gid];
    if (description == null) {
      return null;
    }
    return _TestGlyphData(description);
  }
}

class _TestGlyphData extends GlyphData {
  _TestGlyphData(this._description);

  final GlyphDescription _description;

  @override
  GlyphDescription? get description => _description;
}
