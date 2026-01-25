import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';

/// This represents a Stamp FDF annotation.
class FDFAnnotationStamp extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Stamp';

  /// Default constructor.
  FDFAnnotationStamp() : super() {
    annot.setItem(COSName.subtype, COSName.stamp);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationStamp.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationStamp.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.stamp);
  }
}

