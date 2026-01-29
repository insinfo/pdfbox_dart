import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/cos_objectable.dart';

/// This class represents an external data dictionary.
class PDExternalDataDictionary implements COSObjectable {
  /// Constructor.
  PDExternalDataDictionary([COSDictionary? dictionary])
      : dataDictionary = dictionary ?? COSDictionary() {
    if (dictionary == null) {
      dataDictionary.setName(COSName.type, 'ExData');
    }
  }

  final COSDictionary dataDictionary;

  /// returns the dictionary.
  @override
  COSDictionary get cosObject => dataDictionary;

  /// returns the type of the external data dictionary. It must be "ExData", if present
  String get type =>
      cosObject.getNameAsString(COSName.type, 'ExData') ?? 'ExData';

  /// returns the subtype of the external data dictionary.
  String? get subtype => cosObject.getNameAsString(COSName.subtype);

  /// This will set the subtype of the external data dictionary.
  set subtype(String? subtype) {
    if (subtype == null) {
      cosObject.removeItem(COSName.subtype);
    } else {
      cosObject.setName(COSName.subtype, subtype);
    }
  }
}
