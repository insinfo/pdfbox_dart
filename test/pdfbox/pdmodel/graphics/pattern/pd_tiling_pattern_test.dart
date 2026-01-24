import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_resources.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/pattern/pd_tiling_pattern.dart';
import 'package:pdfbox_dart/src/pdfbox/util/matrix.dart';

void main() {
  test('PDTilingPattern setters roundtrip to COS', () {
    final stream = COSStream();
    stream.setInt(COSName.patternType, 1);
    final pattern = PDTilingPattern(stream);

    pattern.paintType = 1;
    pattern.tilingType = 2;
    pattern.boundingBox = PDRectangle(1, 2, 4, 6);
    pattern.xStep = 10.5;
    pattern.yStep = 20.25;
    pattern.matrix = Matrix.fromComponents(1, 0, 0, 1, 12, 34);

    final resources = PDResources(COSDictionary());
    pattern.patternResources = resources;

    expect(pattern.paintType, equals(1));
    expect(pattern.tilingType, equals(2));
    expect(pattern.boundingBox, isNotNull);
    expect(pattern.boundingBox!.lowerLeftX, equals(1));
    expect(pattern.boundingBox!.lowerLeftY, equals(2));
    expect(pattern.boundingBox!.width, equals(3));
    expect(pattern.boundingBox!.height, equals(4));
    expect(pattern.xStep, equals(10.5));
    expect(pattern.yStep, equals(20.25));
    expect(pattern.matrix.translateX, equals(12));
    expect(pattern.matrix.translateY, equals(34));
    expect(pattern.patternResources, isNotNull);
  });
}
