part of 'pd_shading.dart';

/// Resources for a shading type 6 (Coons Patch Mesh).
/// Port of PDFBox PDShadingType6.java
class PDShadingType6 extends PDMeshBasedShadingType {
  PDShadingType6(COSDictionary dictionary, {dynamic resources})
      : super(dictionary, resources: resources);

  @override
  Patch generatePatch(List<Point> points, List<List<double>> color) {
    return CoonsPatch(points, color);
  }
}

