import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation_text_markup.dart';

/// This represents a Highlight FDF annotation.
class FDFAnnotationHighlight extends FDFAnnotationTextMarkup {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Highlight';

  /// Default constructor.
  FDFAnnotationHighlight() : super() {
    annot.setName(COSName.subtype, SUBTYPE);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationHighlight.fromDictionary(COSDictionary a) : super.fromDictionary(a);
}
