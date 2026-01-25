import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';

/// This represents a Sound FDF annotation.
class FDFAnnotationSound extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Sound';

  /// Default constructor.
  FDFAnnotationSound() : super() {
    annot.setItem(COSName.subtype, COSName.sound);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationSound.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationSound.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.sound);
  }
}

