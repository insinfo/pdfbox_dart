import '../../../utils/xml/xml.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';

/// This represents a FileAttachment FDF annotation.
class FDFAnnotationFileAttachment extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'FileAttachment';

  /// Default constructor.
  FDFAnnotationFileAttachment() : super() {
    annot.setItem(COSName.subtype, COSName.fileAttachment);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationFileAttachment.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationFileAttachment.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.fileAttachment);
  }
}

