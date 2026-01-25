part of 'pd_shading.dart';

/// Resources for a shading type 4 (Free-Form Gouraud-Shaded Triangle Mesh).
/// Port of PDFBox PDShadingType4.java
class PDShadingType4 extends PDTriangleBasedShadingType {
  PDShadingType4(COSDictionary dictionary, {dynamic resources})
      : super(dictionary, resources: resources);

  /// The bits per flag of this shading.
  int get bitsPerFlag => cosObject.getInt(COSName.bitsPerFlag) ?? -1;

  set bitsPerFlag(int value) {
    cosObject.setInt(COSName.bitsPerFlag, value);
  }

  @override
  List<ShadedTriangle> collectTriangles(Affine xform, Matrix matrix) {
    final bpf = bitsPerFlag;
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

    final numColorComponents = numberOfColorComponents;
    final colRange = <PDRange>[];
    for (var i = 0; i < numColorComponents; i++) {
      final range = getDecodeForParameter(2 + i);
      if (range == null) {
        throw StateError('Range missing in shading /Decode entry');
      }
      colRange.add(range);
    }

    final list = <ShadedTriangle>[];
    final maxSrcCoord = (1 << bitsPerCoordinate) - 1;
    final maxSrcColor = (1 << bitsPerComponent) - 1;

    final data = dict.decode();
    if (data == null || data.isEmpty) {
      return <ShadedTriangle>[];
    }

    final input = BitInputStream(data);

    try {
      var flag = input.readBits(bpf) & 3;

      while (!input.isEof) {
        ShadingVertex p0, p1, p2;
        List<Point> ps;
        List<List<double>> cs;

        try {
          switch (flag) {
            case 0:
              p0 = readVertex(input, maxSrcCoord, maxSrcColor, rangeX, rangeY,
                  colRange, matrix, xform);
              flag = input.readBits(bpf) & 3;
              if (flag != 0) {
                // LOG: bad triangle
              }
              p1 = readVertex(input, maxSrcCoord, maxSrcColor, rangeX, rangeY,
                  colRange, matrix, xform);
              input.readBits(bpf);
              p2 = readVertex(input, maxSrcCoord, maxSrcColor, rangeX, rangeY,
                  colRange, matrix, xform);
              ps = [p0.point, p1.point, p2.point];
              cs = [p0.color, p1.color, p2.color];
              list.add(ShadedTriangle(ps, cs));
              if (!input.isEof) {
                flag = input.readBits(bpf) & 3;
              }
              break;
            case 1:
            case 2:
              final lastIndex = list.length - 1;
              if (lastIndex < 0) {
                // LOG: broken data stream
                return list;
              }
              final preTri = list[lastIndex];
              p2 = readVertex(input, maxSrcCoord, maxSrcColor, rangeX, rangeY,
                  colRange, matrix, xform);
              ps = [
                flag == 1 ? preTri.corner[1] : preTri.corner[0],
                preTri.corner[2],
                p2.point
              ];
              cs = [
                flag == 1 ? preTri.color[1] : preTri.color[0],
                preTri.color[2],
                p2.color
              ];
              list.add(ShadedTriangle(ps, cs));
              if (!input.isEof) {
                flag = input.readBits(bpf) & 3;
              }
              break;
            default:
              // LOG: bad flag
              return list;
          }
        } catch (e) {
          // Probably EOF or read error - done parsing
          break;
        }
      }
    } catch (e) {
      // Initial read failed
    }

    return list;
  }
}

