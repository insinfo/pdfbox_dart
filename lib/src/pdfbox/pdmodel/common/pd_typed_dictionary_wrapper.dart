import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';

import 'pd_dictionary_wrapper.dart';

/// [PDDictionaryWrapper] variant that enforces a specific /Type entry.
class PDTypedDictionaryWrapper extends PDDictionaryWrapper {
  PDTypedDictionaryWrapper(String type) : super() {
    cosObject.setName(COSName.type, type);
  }

  PDTypedDictionaryWrapper.fromDictionary(COSDictionary dictionary)
      : super(dictionary);

  String? get type => cosObject.getNameAsString(COSName.type);
}
