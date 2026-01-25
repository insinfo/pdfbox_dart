part of 'pd_shading.dart';

/// Common resources for shading types 6 and 7.
/// Port of PDFBox PDMeshBasedShadingType.java
abstract class PDMeshBasedShadingType extends PDShadingType4 {
  PDMeshBasedShadingType(COSDictionary dictionary, {dynamic resources})
      : super(dictionary, resources: resources);

  /// Create a patch list from a data stream.
  /// [controlPoints] is 12 for type 6 and 16 for type 7.
  List<Patch> collectPatches(Affine xform, Matrix matrix, int controlPoints) {
    final dict = cosObject;

    if (dict is! COSStream) {
      return <Patch>[];
    }

    final rangeX = getDecodeForParameter(0);
    final rangeY = getDecodeForParameter(1);
    if (rangeX == null ||
        rangeY == null ||
        rangeX.min == rangeX.max ||
        rangeY.min == rangeY.max) {
      return <Patch>[];
    }

    final bpf = bitsPerFlag;
    final numColorComponents = numberOfColorComponents;
    final colRange = <PDRange>[];
    for (var i = 0; i < numColorComponents; i++) {
      final range = getDecodeForParameter(2 + i);
      if (range == null) {
        throw StateError('Range missing in shading /Decode entry');
      }
      colRange.add(range);
    }

    final list = <Patch>[];
    final maxSrcCoord = (1 << bitsPerCoordinate) - 1;
    final maxSrcColor = (1 << bitsPerComponent) - 1;

    final data = dict.decode();
    if (data == null || data.isEmpty) {
      return <Patch>[];
    }

    final input = BitInputStream(data);

    var implicitEdge = <Point>[
      const Point(0, 0),
      const Point(0, 0),
      const Point(0, 0),
      const Point(0, 0)
    ];
    var implicitCornerColor = List<List<double>>.generate(
        2, (_) => List<double>.filled(numColorComponents, 0));
    var flag = 0;

    try {
      flag = input.readBits(bpf) & 3;
    } catch (e) {
      return list;
    }

    var eof = false;
    while (!eof) {
      try {
        final isFree = flag == 0;
        final current = _readPatch(
          input,
          isFree,
          implicitEdge,
          implicitCornerColor,
          maxSrcCoord,
          maxSrcColor,
          rangeX,
          rangeY,
          colRange,
          matrix,
          xform,
          controlPoints,
        );
        if (current == null) {
          break;
        }
        list.add(current);

        flag = input.readBits(bpf) & 3;
        switch (flag) {
          case 0:
            break;
          case 1:
            implicitEdge = current.getFlag1Edge();
            implicitCornerColor = current.getFlag1Color();
            break;
          case 2:
            implicitEdge = current.getFlag2Edge();
            implicitCornerColor = current.getFlag2Color();
            break;
          case 3:
            implicitEdge = current.getFlag3Edge();
            implicitCornerColor = current.getFlag3Color();
            break;
          default:
            break;
        }
      } catch (e) {
        eof = true;
      }
    }
    return list;
  }

  Patch? _readPatch(
    BitInputStream input,
    bool isFree,
    List<Point> implicitEdge,
    List<List<double>> implicitCornerColor,
    int maxSrcCoord,
    int maxSrcColor,
    PDRange rangeX,
    PDRange rangeY,
    List<PDRange> colRange,
    Matrix matrix,
    Affine xform,
    int controlPointCount,
  ) {
    final numColorComponents = numberOfColorComponents;
    final color = List<List<double>>.generate(
        4, (_) => List<double>.filled(numColorComponents, 0));
    final points = List<Point>.filled(controlPointCount, const Point(0, 0));

    int pStart;
    int cStart;
    if (isFree) {
      pStart = 0;
      cStart = 0;
    } else {
      pStart = 4;
      cStart = 2;
      points[0] = implicitEdge[0];
      points[1] = implicitEdge[1];
      points[2] = implicitEdge[2];
      points[3] = implicitEdge[3];

      for (var i = 0; i < numColorComponents; i++) {
        color[0][i] = implicitCornerColor[0][i];
        color[1][i] = implicitCornerColor[1][i];
      }
    }

    try {
      for (var i = pStart; i < controlPointCount; i++) {
        final x = input.readBits(bitsPerCoordinate);
        final y = input.readBits(bitsPerCoordinate);
        final px = interpolate(x.toDouble(), maxSrcCoord, rangeX.min, rangeX.max);
        final py = interpolate(y.toDouble(), maxSrcCoord, rangeY.min, rangeY.max);
        final p = matrix.transformPoint(px, py);
        final transformed = xform.transformPoint(p.x, p.y);
        points[i] = Point(transformed.x, transformed.y);
      }

      for (var i = cStart; i < 4; i++) {
        for (var j = 0; j < numColorComponents; j++) {
          final c = input.readBits(bitsPerComponent);
          color[i][j] = interpolate(
              c.toDouble(), maxSrcColor, colRange[j].min, colRange[j].max);
        }
      }
    } catch (e) {
      return null;
    }

    return generatePatch(points, color);
  }

  /// Create a patch using control points and 4 corner color values.
  Patch generatePatch(List<Point> points, List<List<double>> color);

  @override
  List<ShadedTriangle> collectTriangles(Affine xform, Matrix matrix) {
    // Collect patches and flatten their triangles
    final controlPointCount = this is PDShadingType6 ? 12 : 16;
    final patches = collectPatches(xform, matrix, controlPointCount);
    final triangles = <ShadedTriangle>[];
    for (final patch in patches) {
      triangles.addAll(patch.listOfTriangles);
    }
    return triangles;
  }
}

