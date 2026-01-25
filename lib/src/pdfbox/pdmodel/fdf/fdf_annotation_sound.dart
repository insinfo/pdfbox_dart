import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';

/// This represents a Sound FDF annotation.
class FDFAnnotationSound extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Sound';

  /// Default constructor.
  FDFAnnotationSound() : super() {
    annot.setName(COSName.subtype, SUBTYPE);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationSound.fromDictionary(COSDictionary a) : super.fromDictionary(a);
}
