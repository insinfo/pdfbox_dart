import '../../../cos/cos_dictionary.dart';
import 'pd_annotation.dart';

/// Fallback wrapper used when no specific annotation subtype is available.
class PDAnnotationUnknown extends PDAnnotation {
  PDAnnotationUnknown.fromDictionary(COSDictionary dictionary)
      : super.internal(dictionary);
}
