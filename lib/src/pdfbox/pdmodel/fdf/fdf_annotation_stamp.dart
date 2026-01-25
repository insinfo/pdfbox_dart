import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';

/// This represents a Stamp FDF annotation.
class FDFAnnotationStamp extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Stamp';

  /// Default constructor.
  FDFAnnotationStamp() : super() {
    annot.setName(COSName.subtype, SUBTYPE);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationStamp.fromDictionary(COSDictionary a) : super.fromDictionary(a);
}
