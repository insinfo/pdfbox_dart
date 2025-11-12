library pdfbox.pdmodel.property_list;

import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';
import '../../../rendering/render_destination.dart';

part '../../graphics/optionalcontent/pd_optional_content_group.dart';
part '../../graphics/optionalcontent/pd_optional_content_membership_dictionary.dart';

/// Base class for property lists stored in marked content sequences.
class PDPropertyList implements COSObjectable {
  PDPropertyList({COSDictionary? dictionary})
      : dict = dictionary ?? COSDictionary();

  final COSDictionary dict;

  static PDPropertyList create(COSDictionary dictionary) {
    final type = dictionary.getDictionaryObject(COSName.type);
    if (type == COSName.ocg) {
      return PDOptionalContentGroup.fromDictionary(dictionary);
    }
    if (type == COSName.ocmd) {
      return PDOptionalContentMembershipDictionary.fromDictionary(
        dictionary,
      );
    }
    return PDPropertyList(dictionary: dictionary);
  }

  @override
  COSDictionary get cosObject => dict;
}
