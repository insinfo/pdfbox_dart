
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import '../../../../pdmodel/common/pd_destination.dart';
import '../../action/pd_action.dart';
import '../../action/pd_action_go_to.dart';
import 'pd_outline_node.dart';

class PDOutlineItem extends PDOutlineNode {
  PDOutlineItem([COSDictionary? dictionary]) : super(dictionary);

  String? get title => cosObject.getString(COSName.title);


  set title(String? title) {
    cosObject.setString(COSName.title, title);
  }

  PDDestination? get destination {
    final dest = cosObject.getDictionaryObject(COSName.dest);
    if (dest != null) {
      return PDDestination.fromCOS(dest);
    }
    final act = action;
    if (act is PDActionGoTo) {
      return act.destination;
    }
    return null;
  }

  PDAction? get action {
    final dict = cosObject.getDictionaryObject(COSName.a);
    if (dict == null) return null;
    // Currently only GoTo is explicitly wrapped for this use case, but we can expand.
    return PDActionGoTo.fromCOS(dict) as PDAction? ??
        (dict is COSDictionary ? PDActionGoTo(dictionary: dict) : null);
  }
}
