import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation_text_markup.dart';

/// This represents a Underline FDF annotation.
class FDFAnnotationUnderline extends FDFAnnotationTextMarkup {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Underline';

  /// Default constructor.
  FDFAnnotationUnderline() : super() {
    annot.setName(COSName.subtype, SUBTYPE);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationUnderline.fromDictionary(COSDictionary a) : super.fromDictionary(a);
}
