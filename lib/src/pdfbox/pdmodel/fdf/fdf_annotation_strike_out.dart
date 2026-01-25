import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation_text_markup.dart';

/// This represents a StrikeOut FDF annotation.
class FDFAnnotationStrikeOut extends FDFAnnotationTextMarkup {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'StrikeOut';

  /// Default constructor.
  FDFAnnotationStrikeOut() : super() {
    annot.setName(COSName.subtype, SUBTYPE);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationStrikeOut.fromDictionary(COSDictionary a) : super.fromDictionary(a);
}
