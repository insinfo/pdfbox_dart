part of 'pd_shading.dart';

/// Resources for a shading type 7 (Tensor-Product Patch Mesh).
/// Port of PDFBox PDShadingType7.java
class PDShadingType7 extends PDMeshBasedShadingType {
  PDShadingType7(COSDictionary dictionary, {dynamic resources})
      : super(dictionary, resources: resources);

  @override
  Patch generatePatch(List<Point> points, List<List<double>> color) {
    return TensorPatch(points, color);
  }
}
