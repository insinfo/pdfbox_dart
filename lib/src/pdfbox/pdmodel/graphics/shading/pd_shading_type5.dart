part of 'pd_shading.dart';

/// Resources for a shading type 5 (Lattice-Form Gouraud-Shade Triangle Mesh).
/// Port of PDFBox PDShadingType5.java
class PDShadingType5 extends PDTriangleBasedShadingType {
  PDShadingType5(COSDictionary dictionary, {dynamic resources})
      : super(dictionary, resources: resources);

  /// The vertices per row of this shading.
  int get verticesPerRow => cosObject.getInt(COSName.verticesPerRow) ?? -1;

  set verticesPerRow(int value) {
    cosObject.setInt(COSName.verticesPerRow, value);
  }

  @override
  List<ShadedTriangle> collectTriangles(Affine xform, Matrix matrix) {
    final dict = cosObject;

    if (dict is! COSStream) {
      return <ShadedTriangle>[];
    }

    final rangeX = getDecodeForParameter(0);
    final rangeY = getDecodeForParameter(1);
    if (rangeX == null ||
        rangeY == null ||
        rangeX.min == rangeX.max ||
        rangeY.min == rangeY.max) {
      return <ShadedTriangle>[];
    }

    final numPerRow = verticesPerRow;
    if (numPerRow < 2) {
      return <ShadedTriangle>[];
    }

    final numColorComponents = numberOfColorComponents;
    final colRange = <PDRange>[];
    for (var i = 0; i < numColorComponents; i++) {
      final range = getDecodeForParameter(2 + i);
      if (range == null) {
        throw StateError('Range missing in shading /Decode entry');
      }
      colRange.add(range);
    }

    final vlist = <ShadingVertex>[];
    final maxSrcCoord = (1 << bitsPerCoordinate) - 1;
    final maxSrcColor = (1 << bitsPerComponent) - 1;

    final data = dict.decode();
    if (data == null || data.isEmpty) {
      return <ShadedTriangle>[];
    }

    final input = BitInputStream(data);

    while (!input.isEof) {
      try {
        final p = readVertex(input, maxSrcCoord, maxSrcColor, rangeX, rangeY,
            colRange, matrix, xform);
        vlist.add(p);
      } catch (e) {
        // EOF
        break;
      }
    }

    final rowNum = vlist.length ~/ numPerRow;
    if (rowNum < 2) {
      // must have at least two rows
      return <ShadedTriangle>[];
    }

    // Build lattice array
    final latticeArray = List<List<ShadingVertex>>.generate(
        rowNum,
        (i) => List<ShadingVertex>.generate(
            numPerRow, (j) => vlist[i * numPerRow + j]));

    return _createShadedTriangleList(rowNum, numPerRow, latticeArray);
  }

  List<ShadedTriangle> _createShadedTriangleList(
      int rowNum, int numPerRow, List<List<ShadingVertex>> latticeArray) {
    final list = <ShadedTriangle>[];

    for (var i = 0; i < rowNum - 1; i++) {
      for (var j = 0; j < numPerRow - 1; j++) {
        // First triangle
        final ps1 = [
          latticeArray[i][j].point,
          latticeArray[i][j + 1].point,
          latticeArray[i + 1][j].point
        ];
        final cs1 = [
          latticeArray[i][j].color,
          latticeArray[i][j + 1].color,
          latticeArray[i + 1][j].color
        ];
        list.add(ShadedTriangle(ps1, cs1));

        // Second triangle
        final ps2 = [
          latticeArray[i][j + 1].point,
          latticeArray[i + 1][j].point,
          latticeArray[i + 1][j + 1].point
        ];
        final cs2 = [
          latticeArray[i][j + 1].color,
          latticeArray[i + 1][j].color,
          latticeArray[i + 1][j + 1].color
        ];
        list.add(ShadedTriangle(ps2, cs2));
      }
    }

    return list;
  }
}
