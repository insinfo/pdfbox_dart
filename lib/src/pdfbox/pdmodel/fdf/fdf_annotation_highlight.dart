import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation_text_markup.dart';

/// This represents a Highlight FDF annotation.
class FDFAnnotationHighlight extends FDFAnnotationTextMarkup {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Highlight';

  /// Default constructor.
  FDFAnnotationHighlight() : super() {
    annot.setItem(COSName.subtype, COSName.highlight);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationHighlight.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationHighlight.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.highlight);
  }
}


