import '../../../utils/xml/xml.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';

/// This represents a Link FDF annotation.
class FDFAnnotationLink extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Link';

  /// Default constructor.
  FDFAnnotationLink() : super() {
    annot.setItem(COSName.subtype, COSName.link);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationLink.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationLink.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.link);
  }
}

