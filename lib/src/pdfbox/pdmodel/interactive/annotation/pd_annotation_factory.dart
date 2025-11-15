import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';
import 'pd_annotation.dart';
import 'pd_annotation_link.dart';
import 'pd_annotation_text.dart';
import 'pd_annotation_unknown.dart';
import 'pd_annotation_widget.dart';

/// Factory that maps annotation dictionaries to typed wrappers.
class PDAnnotationFactory {
  const PDAnnotationFactory._();

  static const PDAnnotationFactory instance = PDAnnotationFactory._();

  PDAnnotation? createAnnotation(COSBase? base) {
    if (base == null) {
      return null;
    }
    final dictionaryBase = base is COSObject ? base.object : base;
    if (dictionaryBase is! COSDictionary) {
      return null;
    }
    final cached = PDAnnotation.getCached(dictionaryBase);
    if (cached != null) {
      return cached;
    }
    final subtype = dictionaryBase.getNameAsString(COSName.subtype);
    switch (subtype) {
      case 'Link':
        return PDAnnotationLink.fromDictionary(dictionaryBase);
      case 'Text':
        return PDAnnotationText.fromDictionary(dictionaryBase);
      case 'Widget':
        return PDAnnotationWidget.fromDictionary(dictionaryBase);
      default:
        return PDAnnotationUnknown.fromDictionary(dictionaryBase);
    }
  }
}
