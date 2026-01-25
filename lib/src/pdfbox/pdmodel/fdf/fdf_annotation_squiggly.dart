import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation_text_markup.dart';

/// This represents a Squiggly FDF annotation.
class FDFAnnotationSquiggly extends FDFAnnotationTextMarkup {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Squiggly';

  /// Default constructor.
  FDFAnnotationSquiggly() : super() {
    annot.setItem(COSName.subtype, COSName.squiggly);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationSquiggly.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationSquiggly.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.squiggly);
  }
}

