import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation_text_markup.dart';

/// This represents a StrikeOut FDF annotation.
class FDFAnnotationStrikeOut extends FDFAnnotationTextMarkup {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'StrikeOut';

  /// Default constructor.
  FDFAnnotationStrikeOut() : super() {
    annot.setItem(COSName.subtype, COSName.strikeOut);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationStrikeOut.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationStrikeOut.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.strikeOut);
  }
}

