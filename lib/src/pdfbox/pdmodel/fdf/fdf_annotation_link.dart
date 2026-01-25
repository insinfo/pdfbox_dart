import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';

/// This represents a Link FDF annotation.
class FDFAnnotationLink extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Link';

  /// Default constructor.
  FDFAnnotationLink() : super() {
    annot.setName(COSName.subtype, SUBTYPE);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationLink.fromDictionary(COSDictionary a) : super.fromDictionary(a);
}
