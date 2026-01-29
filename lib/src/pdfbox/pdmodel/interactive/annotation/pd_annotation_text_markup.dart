import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import 'pd_annotation_markup.dart';

/// This is the abstract class that represents a text markup annotation introduced in the PDF 1.3
/// specification, except Squiggly lines in 1.4.
abstract class PDAnnotationTextMarkup extends PDAnnotationMarkup {
  /// Creates a TextMarkup annotation of the specified sub type.
  PDAnnotationTextMarkup(String subType, [COSDictionary? dict])
      : super(dict ?? COSDictionary()) {
    if (dict == null) {
      setSubtype(subType);
      // Quad points are required, set an empty array
      setQuadPoints(<double>[]);
    }
  }

  /// Creates a TextMarkup annotation from a COSDictionary, expected to be a correct object definition.
  PDAnnotationTextMarkup.fromDictionary(COSDictionary field) : super(field);

  /// This will set the set of quadpoints which encompass the areas of this annotation.
  ///
  /// [quadPoints] an array representing the set of area covered
  void setQuadPoints(List<double> quadPoints) {
    dictionary.setItem(
        COSName.quadPoints,
        COSArray(quadPoints.map((e) => COSFloat(e))));
  }

  /// This will retrieve the set of quadpoints which encompass the areas of this annotation.
  ///
  /// Returns An array of floats representing the quad points.
  List<double>? getQuadPoints() {
    final array = dictionary.getCOSArray(COSName.quadPoints);
    return array?.toDoubleList();
  }

  void setSubtype(String subType) {
    dictionary.setName(COSName.subtype, subType);
  }
}
