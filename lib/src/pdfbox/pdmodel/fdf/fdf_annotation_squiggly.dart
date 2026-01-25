import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation_text_markup.dart';

/// This represents a Squiggly FDF annotation.
class FDFAnnotationSquiggly extends FDFAnnotationTextMarkup {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Squiggly';

  /// Default constructor.
  FDFAnnotationSquiggly() : super() {
    annot.setName(COSName.subtype, SUBTYPE);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationSquiggly.fromDictionary(COSDictionary a) : super.fromDictionary(a);
}
