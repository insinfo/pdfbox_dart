import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation_text_markup.dart';

/// This represents a Underline FDF annotation.
class FDFAnnotationUnderline extends FDFAnnotationTextMarkup {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Underline';

  /// Default constructor.
  FDFAnnotationUnderline() : super() {
    annot.setItem(COSName.subtype, COSName.underline);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationUnderline.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationUnderline.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.underline);
  }
}

