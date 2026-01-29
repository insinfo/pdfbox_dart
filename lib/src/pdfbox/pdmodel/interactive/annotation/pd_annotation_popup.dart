import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_annotation.dart';
import 'pd_annotation_markup.dart';

/// This is the class that represents a popup annotation. Introduced in PDF 1.3 specification.
class PDAnnotationPopup extends PDAnnotation {
  /// The type of annotation.
  static const String subType = 'Popup';

  /// Constructor.
  PDAnnotationPopup([COSDictionary? field])
      : super.internal(field ?? COSDictionary()) {
    if (field == null) {
      dictionary.setName(COSName.subtype, subType);
    }
  }

  /// This will set the initial state of the annotation, open or closed.
  set open(bool open) => dictionary.setBoolean(COSName.open, open);

  /// This will retrieve the initial state of the annotation, open Or closed (default closed).
  bool get open => dictionary.getBoolean(COSName.open, false) ?? false;

  /// This will set the markup annotation which this popup relates to.
  set parent(PDAnnotationMarkup? annot) {
    if (annot == null) {
      dictionary.removeItem(COSName.parent);
    } else {
      dictionary.setItem(COSName.parent, annot.cosObject);
    }
  }

  /// This will retrieve the markup annotation which this popup relates to.
  PDAnnotationMarkup? get parent {
    final dict = dictionary.getDictionaryObject(COSName.parent);
    // TODO: We need a reliable way to create the specific annotation type.
    // Use PDAnnotation.createAnnotation logic here once available.
    if (dict is COSDictionary) {
      // For now, assuming it is a Markup annotation if it has the fields,
      // but in Dart we might need to check subtype or cast.
      // Since we don't have the full factory yet, returning PDAnnotationMarkup directly wrapper
      return PDAnnotationMarkup(dict);
    }
    return null;
  }
}
